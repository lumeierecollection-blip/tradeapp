import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/github_data_service.dart';
import '../../services/price_history_service.dart';
import '../theme.dart';
import '../widgets/price_chart.dart';
import 'signal_detail_screen.dart';

/// Model-published signals (ml_latest.json, falling back to the rule-based
/// latest.json) fetched from GitHub. Display only — nothing here trades.
class ModelSignalsScreen extends StatefulWidget {
  final GithubDataService? data;
  final PriceHistoryService? priceHistory;
  final Duration refreshInterval;

  const ModelSignalsScreen({
    super.key,
    this.data,
    this.priceHistory,
    this.refreshInterval = const Duration(seconds: 60),
  });

  @override
  State<ModelSignalsScreen> createState() => _ModelSignalsScreenState();
}

class _ModelSignalsScreenState extends State<ModelSignalsScreen> {
  late final GithubDataService _data = widget.data ?? GithubDataService();
  bool _loading = true;
  bool _error = false;
  List<Map<String, dynamic>> _signals = [];
  DateTime? _timestamp;
  bool _isMl = false;
  String? _filter; // null = All
  Timer? _refreshTimer;
  DateTime? _lastUpdate;

  @override
  void initState() {
    super.initState();
    _load().whenComplete(() {
      if (mounted) _startTimer();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(widget.refreshInterval, (_) => _refresh());
  }

  /// Timer tick: re-fetch past the cache without blanking the list.
  Future<void> _refresh() => _load(force: true, silent: true);

  /// Manual refresh (button / pull): fetch now and restart the countdown.
  Future<void> _refreshNow() async {
    _startTimer();
    await _load(force: true, silent: !_error && _signals.isNotEmpty);
  }

  Future<void> _load({bool force = false, bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = false; });
    final results = await Future.wait([
      _data.getMlSignals(force: force),
      _data.getLatestSignals(force: force),
    ]);
    if (!mounted) return;
    final ml = results[0];
    final rules = results[1];
    final mlSignals = _parseSignals(ml);
    final rulesSignals = _parseSignals(rules);

    // Prefer ML; fall back to rule-based when the ML file is empty or missing.
    final useMl = mlSignals != null && mlSignals.isNotEmpty;
    final source = useMl ? ml : rules;
    setState(() {
      _loading = false;
      // Neither file came back at all (404, network, bad JSON).
      _error = mlSignals == null && rulesSignals == null;
      _isMl = useMl;
      _signals = (useMl ? mlSignals : rulesSignals) ?? [];
      _timestamp = DateTime.tryParse(source['timestamp']?.toString() ?? '');
      _lastUpdate = DateTime.now();
    });
  }

  /// The payload's signal rows, or null when the payload didn't load.
  List<Map<String, dynamic>>? _parseSignals(Map<String, dynamic> payload) {
    final raw = payload['signals'];
    if (raw is! List) return null;
    return raw.whereType<Map>().map((r) => Map<String, dynamic>.from(r)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Model Signals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _refreshNow,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshNow,
              child: _error
                  ? _centered(
                      children: [
                        const Icon(Icons.cloud_off, size: 40, color: AppTheme.sell),
                        const SizedBox(height: 12),
                        const Text('Could not load signals. Tap to retry.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textSecondary)),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _refreshNow, child: const Text('Retry')),
                      ],
                    )
                  : _signals.isEmpty
                      ? _centered(children: [
                          _freshnessBanner(),
                          const SizedBox(height: 24),
                          const Text('No signals yet. Workflows run every 4 hours.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textMuted)),
                        ])
                      : _list(),
            ),
      bottomNavigationBar: const Padding(
        padding: EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: Text(
          'Informational only. Yahoo data is 15–20 min delayed. Not financial advice.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
        ),
      ),
    );
  }

  /// Scrollable so pull-to-refresh still works on the empty/error states.
  Widget _centered({required List<Widget> children}) {
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: children),
          ),
        ],
      ),
    );
  }

  Widget _list() {
    final visible = _filter == null
        ? _signals
        : _signals.where((s) => (s['signal'] ?? '').toString().toUpperCase() == _filter).toList();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      children: [
        _freshnessBanner(),
        const SizedBox(height: 8),
        _statusRow(),
        const SizedBox(height: 4),
        _filterChips(),
        const SizedBox(height: 8),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text('No $_filter signals right now.',
                textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textMuted)),
          ),
        ...visible.map(_signalCard),
      ],
    );
  }

  Widget _freshnessBanner() {
    final ts = _timestamp;
    final age = ts == null ? null : DateTime.now().toUtc().difference(ts.toUtc());
    final Color color;
    final String ageText;
    if (age == null) {
      color = AppTheme.sell;
      ageText = 'no timestamp';
    } else {
      color = age < const Duration(hours: 1)
          ? AppTheme.buy
          : age <= const Duration(hours: 6)
              ? AppTheme.warn
              : AppTheme.sell;
      ageText = _formatAge(age);
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_isMl ? 'ML model (LightGBM)' : 'Rule-based'} · updated $ageText',
              style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  String _formatAge(Duration age) {
    if (age.isNegative || age.inMinutes < 1) return 'just now';
    if (age.inHours < 1) return '${age.inMinutes}m ago';
    if (age.inDays < 1) return '${age.inHours}h ago';
    return '${age.inDays}d ago';
  }

  Widget _filterChips() {
    Widget chip(String label, String? value) {
      final count = value == null
          ? _signals.length
          : _signals.where((s) => (s['signal'] ?? '').toString().toUpperCase() == value).length;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text('$label ($count)'),
          selected: _filter == value,
          onSelected: (_) => setState(() => _filter = value),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        chip('All', null),
        chip('BUY', 'BUY'),
        chip('SELL', 'SELL'),
        chip('HOLD', 'HOLD'),
      ]),
    );
  }

  Color _signalColor(String signal) {
    switch (signal) {
      case 'BUY':
        return AppTheme.buy;
      case 'SELL':
        return AppTheme.sell;
      default:
        return AppTheme.textMuted;
    }
  }

  Widget _statusRow() {
    final t = _lastUpdate;
    final stamp = t == null
        ? '—'
        : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
    return Row(
      children: [
        Expanded(
          // Keyed on the update time so the text flashes accent → muted on every refresh.
          child: TweenAnimationBuilder<Color?>(
            key: ValueKey(t),
            tween: ColorTween(begin: AppTheme.accent2, end: AppTheme.textMuted),
            duration: const Duration(milliseconds: 900),
            builder: (context, color, _) => Text(
              'Auto-refresh every ${widget.refreshInterval.inSeconds}s • last update $stamp',
              style: TextStyle(fontSize: 11, color: color),
            ),
          ),
        ),
        TextButton.icon(
          onPressed: _loading ? null : _refreshNow,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Refresh now', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  Widget _signalCard(Map<String, dynamic> s) {
    final symbol = (s['symbol'] ?? '').toString();
    final signal = (s['signal'] ?? 'HOLD').toString().toUpperCase();
    final confidence = s['confidence'];
    final price = s['price'];
    final regime = s['regime'];
    final color = _signalColor(signal);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SignalDetailScreen(signal: s, priceHistory: widget.priceHistory),
        )),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(symbol, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(price is num ? AppTheme.fmtQuote(symbol, price.toDouble()) : '—',
                                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                            if (regime != null) ...[
                              const SizedBox(width: 8),
                              _pill(regime.toString(), AppTheme.textSecondary),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _pill(signal, color, filled: true),
                      const SizedBox(height: 6),
                      if (confidence is num) _confidenceText(confidence.toDouble()),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 40,
                child: PriceHistoryChart(
                  symbol: symbol,
                  color: signalLineColor(signal),
                  service: widget.priceHistory,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _confidenceText(double c) {
    final TextStyle style;
    if (c > 0.75) {
      style = const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary);
    } else if (c >= 0.5) {
      style = const TextStyle(fontSize: 14, color: AppTheme.textPrimary);
    } else {
      style = const TextStyle(fontSize: 14, color: AppTheme.textMuted);
    }
    return Text('${(c * 100).round()}%', style: style);
  }

  Widget _pill(String text, Color color, {bool filled = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.2) : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(text,
          style: TextStyle(fontSize: filled ? 12 : 10, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.5)),
    );
  }
}
