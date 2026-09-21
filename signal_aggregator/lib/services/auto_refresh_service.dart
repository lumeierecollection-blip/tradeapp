import 'dart:async';
import 'package:flutter/material.dart';
import 'github_data_service.dart';

/// Periodically fetches GitHub-hosted JSON data (signals, backtest, trades)
/// and notifies listeners when fresh data arrives. Intended to be provided
/// via [ChangeNotifierProvider] at the top of the widget tree.
class AutoRefreshService extends ChangeNotifier {
  final GithubDataService _dataService = GithubDataService();
  Timer? _timer;
  bool _isRefreshing = false;

  Map<String, dynamic>? _latestSignals;
  Map<String, dynamic>? _backtestResults;
  List<dynamic>? _tradeHistory;

  Map<String, dynamic>? get latestSignals => _latestSignals;
  Map<String, dynamic>? get backtestResults => _backtestResults;
  List<dynamic>? get tradeHistory => _tradeHistory;

  /// Starts the periodic refresh loop. Fetches immediately, then every 60 s.
  /// Safe to call multiple times — previous timer is cancelled first.
  void startAutoRefresh() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      _refreshData();
    });
    _refreshData();
  }

  /// Stops the periodic refresh loop.
  void stopAutoRefresh() {
    _timer?.cancel();
    _timer = null;
  }

  /// Fetches all GitHub JSON endpoints in parallel. Errors are swallowed so
  /// a single failed fetch doesn't crash the app.
  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      final results = await Future.wait([
        _dataService.getLatestSignals(),
        _dataService.getBacktestResults(),
        _dataService.getTradeHistory(),
      ]);

      _latestSignals = results[0];
      _backtestResults = results[1];
      _tradeHistory = results[2];
    } catch (e) {
      // swallow errors — don't crash
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
