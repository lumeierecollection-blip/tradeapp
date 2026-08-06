import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import '../models/market_snapshot.dart';
import '../models/paper_trade.dart';
import '../models/signal.dart';
import '../models/validated_signal.dart';
import '../models/goal_plan.dart';
import '../services/background.dart';
import '../services/cloud_backend.dart';
import '../services/market_service.dart';
import '../services/notifications.dart';
import '../services/paper_trader.dart';
import '../services/push.dart';
import '../services/sources/market_pulse_source.dart';
import '../services/sources/signal_source.dart';
import '../services/sources/source_registry.dart';
import '../services/storage.dart';
import '../services/validator.dart';
import '../ui/theme.dart';

class AppState extends ChangeNotifier {
  static const Duration refreshInterval = Duration(seconds: 15);

  final Storage storage;
  final PaperTrader paperTrader;
  final MarketService _marketService = MarketService();
  final SourceRegistry _sourceRegistry = SourceRegistry();
  final Validator _validator = Validator();
  final NotificationService notifications = NotificationService();
  final PushService push = PushService();
  CloudBackend? _cloudBackend;

  List<String> _watchlist = [];
  List<String> _telegramChannels = [];
  Map<String, bool> _sourcesEnabled = {};
  bool _notificationsEnabled = true;
  bool _notificationsReady = false;
  String _goalPlanId = 'realistic-w1';
  bool _realPhase = false;
  bool _cloudEnabled = true;
  String _cloudUrl = '';

  List<Signal> _rawSignals = [];
  Map<String, MarketSnapshot> _markets = {};
  List<ValidatedSignal> _validated = [];
  DateTime? _lastUpdated;
  bool _isLoading = false;
  String? _error;
  Timer? _timer;
  int _updateTick = 0;
  DateTime? _lastFullScan;

  List<ValidatedSignal> get validated => List.unmodifiable(_validated);
  List<Signal> get rawSignals => List.unmodifiable(_rawSignals);
  Map<String, MarketSnapshot> get markets => Map.unmodifiable(_markets);
  List<String> get watchlist => List.unmodifiable(_watchlist);
  List<String> get telegramChannels => List.unmodifiable(_telegramChannels);
  Map<String, bool> get sourcesEnabled => Map.unmodifiable(_sourcesEnabled);
  bool get notificationsEnabled => _notificationsEnabled;
  bool get notificationsReady => _notificationsReady;
  bool get pushSupported => push.isSupported;
  bool get pushReady => push.isReady;
  GoalPlan get goalPlan => GoalPlan.byId(_goalPlanId);
  bool get realPhase => _realPhase;
  bool get cloudEnabled => _cloudEnabled;
  String get cloudUrl => _cloudUrl;
  DateTime? get lastUpdated => _lastUpdated;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Incremented after every successful data update so the UI can play a
  /// subtle "just refreshed" animation without a full reload.
  int get updateTick => _updateTick;

  AppState(this.storage, this.paperTrader) {
    _watchlist = storage.getWatchlist();
    _telegramChannels = storage.getTelegramChannels();
    _sourcesEnabled = storage.getSourcesEnabled();
    _notificationsEnabled = storage.notificationsEnabled;
    _goalPlanId = storage.goalPlanId;
    _realPhase = storage.isRealPhase;
    _cloudEnabled = storage.cloudEnabled;
    _cloudUrl = storage.cloudUrl;
    _sourceRegistry.refreshChannels(_telegramChannels);
    _rebuildCloudBackend();
  }

  void _rebuildCloudBackend() {
    _cloudBackend?.dispose();
    _cloudBackend = _cloudUrl.trim().isEmpty ? null : CloudBackend(baseUrl: CloudBackend.normalize(_cloudUrl));
  }

  void startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(refreshInterval, (_) => refresh());
  }

  Future<void> initNotifications() async {
    await notifications.init();
    _notificationsReady = true;
    notifyListeners();
  }

  Future<void> initPush() async {
    await push.init(backend: _cloudBackend, notifications: notifications);
    notifyListeners();
  }

  Future<void> syncPushRegistration() async {
    if (!push.isReady) return;
    if (_cloudEnabled && _cloudBackend != null && _notificationsEnabled) {
      await push.registerCurrentToken();
    }
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    await storage.setNotificationsEnabled(value);
    if (value && !_notificationsReady) {
      await initNotifications();
    }
    notifyListeners();
    await syncPushRegistration();
  }

  Future<void> setGoalPlan(String id) async {
    _goalPlanId = id;
    await storage.setGoalPlanId(id);
    notifyListeners();
  }

  Future<void> setPhase(bool real) async {
    _realPhase = real;
    await storage.setPhase(real);
    notifyListeners();
  }

  Future<void> setWatchlist(List<String> value) async {
    _watchlist = value.where((s) => s.isNotEmpty).toSet().toList();
    await storage.setWatchlist(_watchlist);
    notifyListeners();
    refresh();
  }

  Future<void> setTelegramChannels(List<String> value) async {
    _telegramChannels = value.where((s) => s.isNotEmpty).toSet().toList();
    await storage.setTelegramChannels(_telegramChannels);
    _sourceRegistry.refreshChannels(_telegramChannels);
    notifyListeners();
    refresh();
  }

  Future<void> setSourceEnabled(String key, bool enabled) async {
    _sourcesEnabled[key] = enabled;
    await storage.setSourcesEnabled(_sourcesEnabled);
    notifyListeners();
    refresh();
  }

  Future<void> setCloudEnabled(bool enabled) async {
    _cloudEnabled = enabled;
    await storage.setCloudEnabled(enabled);
    notifyListeners();
    refresh();
    await syncPushRegistration();
  }

  Future<void> setCloudUrl(String url) async {
    _cloudUrl = url.trim();
    await storage.setCloudUrl(_cloudUrl);
    _rebuildCloudBackend();
    notifyListeners();
    refresh();
    await syncPushRegistration();
  }

  List<SignalSource> get _activeSources => _sourceRegistry.enabled(
        (s) => _sourcesEnabled[s.key] ?? (s.key == 'telegram' ? false : true),
      );

  Future<void> refresh() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      var ok = false;
      if (_cloudEnabled && _cloudBackend != null) {
        try {
          final result = await _cloudBackend!.fetchSignals();
          await _notifyNewStrongSignals(result.validated);
          _rawSignals = result.signals;
          _markets = result.markets;
          _validated = _dedupe(result.validated);
          ok = true;
        } catch (_) {
          _error = 'Cloud feed offline — using on-device scan.';
        }
      }

      if (!ok) {
        await _localScan();
        if (_cloudEnabled && _cloudBackend != null) {
          _error = 'Cloud feed offline — showing on-device scan.';
        }
      }
      _lastUpdated = DateTime.now();
      _updateTick++;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _localScan() async {
    final now = DateTime.now();
    final fullDue = _lastFullScan == null ||
        now.difference(_lastFullScan!) >= const Duration(minutes: 1);

    // Full scans hit Reddit/news/telegram and every market; do them at most
    // once a minute. In between, just refresh watchlist prices so the 15s
    // quiet updates stay cheap and don't hammer third-party APIs.
    if (!fullDue) {
      final markets = await _marketService.fetchSnapshots(_watchlist);
      if (markets.isNotEmpty) {
        final merged = Map<String, MarketSnapshot>.from(_markets)..addAll(markets);
        _markets = merged;
        notifyListeners();
      }
      return;
    }
    _lastFullScan = now;

    final active = _activeSources;
    final rawSignals = await _sourceRegistry.fetchAll(active);

    // Cover the whole universe so every market has live data and the market
    // pulse can evaluate all of them, not just coins with social chatter.
    final markets = await _marketService.fetchSnapshots(MarketService.allSymbols);

    final allSignals = List<Signal>.from(rawSignals);
    if (_sourcesEnabled['pulse'] ?? true) {
      allSignals.addAll(const MarketPulseSource().generate(markets));
    }

    final validated = _validate(allSignals, markets);

    await _notifyNewStrongSignals(validated);
    _rawSignals = allSignals;
    _markets = markets;
    _validated = validated;
  }

  /// Validates every signal and keeps only the best one per market so the
  /// signals list reads one strong move per coin instead of Bitcoin spam.
  List<ValidatedSignal> _validate(
      List<Signal> signals, Map<String, MarketSnapshot> markets) {
    final best = <String, ValidatedSignal>{};
    for (final signal in signals) {
      final vs = _validator.validate(signal, markets);
      if (vs == null) continue;
      final existing = best[vs.symbol];
      if (existing == null || vs.probability > existing.probability) {
        best[vs.symbol] = vs;
      }
    }
    final validated = best.values.toList()
      ..sort((a, b) => b.probability.compareTo(a.probability));
    return validated;
  }

  List<ValidatedSignal> _dedupe(List<ValidatedSignal> signals) {
    final best = <String, ValidatedSignal>{};
    for (final vs in signals) {
      final existing = best[vs.symbol];
      if (existing == null || vs.probability > existing.probability) {
        best[vs.symbol] = vs;
      }
    }
    final validated = best.values.toList()
      ..sort((a, b) => b.probability.compareTo(a.probability));
    return validated;
  }

  Future<void> _notifyNewStrongSignals(List<ValidatedSignal> next) async {
    if (!_notificationsEnabled || !_notificationsReady) return;
    final previousIds = _validated.map((v) => '${v.symbol}-${v.signal.id}').toSet();
    for (final vs in next.take(6)) {
      final id = '${vs.symbol}-${vs.signal.id}';
      if (vs.probability >= 70 && !previousIds.contains(id)) {
        await notifications.showSignalAlert(
          vs.symbol,
          '${vs.direction.label} ${vs.symbol}',
          'Rightness ${vs.probability.round()}% · buy at ${AppTheme.fmtClock(vs.buyAt)} · sell at ${AppTheme.fmtClock(vs.sellAt)}.',
        );
      }
    }
  }

  void startBackgroundWorker() {
    Workmanager().initialize(backgroundFetchDispatcher);
    Workmanager().registerPeriodicTask(
      'signal-fetch-15',
      'signalFetch',
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  }

  /// Opens a paper position and schedules close reminders (5 min, 2 min and
  /// exactly at the signal's close time). Returns an error message, or '' on
  /// success.
  Future<String> openTrade(ValidatedSignal vs, double amount,
      {PositionType type = PositionType.accumulate}) async {
    final result = paperTrader.openTrade(vs, amount, type: type);
    if (result.isNotEmpty) return result;
    final trade = paperTrader.openTrades.first;
    try {
      await notifications.requestPermission();
    } catch (_) {}
    await notifications.scheduleTradeReminders(trade.id, trade.symbol, trade.sellAt);
    return '';
  }

  void closeTrade(String id, {String? closedBy}) {
    paperTrader.closeTrade(id, closedBy: closedBy);
    notifications.cancelTradeReminders(id);
  }

  void closeAtMarket(String id, double price) {
    paperTrader.closeAtMarket(id, price);
    notifications.cancelTradeReminders(id);
  }

  double priceOf(String symbol) => _markets[symbol]?.price ?? 0;

  @override
  void dispose() {
    _timer?.cancel();
    _marketService.dispose();
    _cloudBackend?.dispose();
    super.dispose();
  }
}
