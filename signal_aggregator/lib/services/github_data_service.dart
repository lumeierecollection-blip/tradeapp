import 'dart:convert';
import 'package:http/http.dart' as http;

class GithubDataService {
  static const String _baseUrl =
      'https://raw.githubusercontent.com/lumeierecollection-blip/tradeapp/main/signal_aggregator';

  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _cacheAt = {};
  static const Duration _cacheTtl = Duration(seconds: 60);

  /// Rule-based signals. `{}` when unreachable (404, network, bad JSON) — never throws.
  Future<Map<String, dynamic>> getLatestSignals({bool force = false}) async {
    return _fetchCached('signals', '$_baseUrl/data/signals/latest.json', (data) => data, force: force);
  }

  /// LightGBM signals. `{}` when unreachable (404, network, bad JSON) — never throws.
  Future<Map<String, dynamic>> getMlSignals({bool force = false}) async {
    return _fetchCached('ml_signals', '$_baseUrl/data/signals/ml_latest.json', (data) => data, force: force);
  }

  Future<Map<String, dynamic>> getBacktestResults() async {
    return _fetchCached('backtest', '$_baseUrl/data/backtest/results.json', (data) => data);
  }

  Future<Map<String, dynamic>> getBacktestMatrix() async {
    return _fetchCached('matrix', '$_baseUrl/data/backtest/matrix.json', (data) => data);
  }

  Future<Map<String, dynamic>> getWalkForwardMatrix() async {
    return _fetchCached('wf_matrix', '$_baseUrl/data/backtest/wf_matrix.json', (data) => data);
  }

  Future<Map<String, dynamic>> getValidationSummary() async {
    return _fetchCached('validation', '$_baseUrl/data/backtest/validation_summary.json', (data) => data);
  }

  Future<List<dynamic>> getTradeHistory() async {
    return _fetchCached('trades', '$_baseUrl/data/trades/history.json', (data) => data);
  }

  Future<T> _fetchCached<T>(String key, String url, T Function(dynamic) parse, {bool force = false}) async {
    final cached = _cache[key];
    final cachedAt = _cacheAt[key];
    if (!force && cached != null && cachedAt != null && DateTime.now().difference(cachedAt) < _cacheTtl) {
      return cached as T;
    }
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final parsed = parse(data);
        _cache[key] = parsed;
        _cacheAt[key] = DateTime.now();
        return parsed;
      }
    } catch (_) {
      // swallow errors
    }
    // Return empty structures on failure
    if (T == List) return [] as T;
    return {} as T;
  }
}
