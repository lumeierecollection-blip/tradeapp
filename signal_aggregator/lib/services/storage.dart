import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class Storage {
  static const _kWatchlist = 'watchlist';
  static const _kTelegramChannels = 'telegram_channels';
  static const _kSourcesEnabled = 'sources_enabled';
  static const _kPaperBalance = 'paper_balance';
  static const _kTrades = 'paper_trades';
  static const _kNotifications = 'notifications_enabled';
  static const _kStartBalance = 'start_balance';
  static const _kGoalPlan = 'goal_plan_id';
  static const _kPhase = 'phase';
  static const _kCloudEnabled = 'cloud_enabled';
  static const _kCloudUrl = 'cloud_url';

  static const List<String> defaultWatchlist = ['BTC', 'ETH', 'SOL', 'BNB', 'XRP'];
  static const List<String> defaultTelegramChannels = [
    'BitcoinBullets',
    'fatpigsignals',
    'learn2trade',
    'cryptoinnercircle',
    'binancesignals',
  ];

  final SharedPreferences _prefs;

  Storage._(this._prefs);

  static Future<Storage> load() async =>
      Storage._(await SharedPreferences.getInstance());

  List<String> getWatchlist() =>
      _prefs.getStringList(_kWatchlist) ?? defaultWatchlist;

  Future<void> setWatchlist(List<String> value) =>
      _prefs.setStringList(_kWatchlist, value);

  List<String> getTelegramChannels() =>
      _prefs.getStringList(_kTelegramChannels) ?? defaultTelegramChannels;

  Future<void> setTelegramChannels(List<String> value) =>
      _prefs.setStringList(_kTelegramChannels, value);

  Map<String, bool> getSourcesEnabled() {
    final raw = _prefs.getString(_kSourcesEnabled);
    if (raw == null) return {'reddit': true, 'news': true, 'telegram': true};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, v as bool));
  }

  Future<void> setSourcesEnabled(Map<String, bool> value) =>
      _prefs.setString(_kSourcesEnabled, jsonEncode(value));

  double get paperBalance => _prefs.getDouble(_kPaperBalance) ?? 500.0;

  Future<void> setPaperBalance(double value) =>
      _prefs.setDouble(_kPaperBalance, value);

  double get startBalance => _prefs.getDouble(_kStartBalance) ?? 500.0;

  Future<void> setStartBalance(double value) =>
      _prefs.setDouble(_kStartBalance, value);

  List<Map<String, dynamic>> getTradesJson() {
    final raw = _prefs.getString(_kTrades);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> setTradesJson(List<Map<String, dynamic>> value) =>
      _prefs.setString(_kTrades, jsonEncode(value));

  bool get notificationsEnabled => _prefs.getBool(_kNotifications) ?? true;

  Future<void> setNotificationsEnabled(bool value) =>
      _prefs.setBool(_kNotifications, value);

  String get goalPlanId => _prefs.getString(_kGoalPlan) ?? 'realistic-w1';

  Future<void> setGoalPlanId(String value) => _prefs.setString(_kGoalPlan, value);

  bool get isRealPhase => _prefs.getBool(_kPhase) ?? false;

  Future<void> setPhase(bool real) => _prefs.setBool(_kPhase, real);

  bool get cloudEnabled => _prefs.getBool(_kCloudEnabled) ?? true;

  Future<void> setCloudEnabled(bool value) => _prefs.setBool(_kCloudEnabled, value);

  String get cloudUrl => _prefs.getString(_kCloudUrl) ?? '';

  Future<void> setCloudUrl(String value) => _prefs.setString(_kCloudUrl, value);
}
