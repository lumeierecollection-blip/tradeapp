import 'dart:convert';
import 'package:http/http.dart' as http;

class GithubDataService {
  static const String _baseUrl =
      'https://raw.githubusercontent.com/lumeierecollection-blip/tradeapp/main/signal_aggregator';

  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _cacheAt = {};
  static const Duration _cacheTtl = Duration(seconds: 60);

  Future<Map<String, dynamic>> getLatestSignals() async {
    return _fetchCached('signals', '$_baseUrl/data/signals/latest.json', (data) => data);
  }

  Future<Map<String, dynamic>> getMlSignals() async {
    return _fetchCached('ml_signals', '$_baseUrl/data/signals/ml_latest.json', (data) => data);
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

  Future<List<dynamic>> getTradeHistory() async {
    return _fetchCached('trades', '$_baseUrl/data/trades/history.json', (data) => data);
  }

  Future<T> _fetchCached<T>(String key, String url, T Function(dynamic) parse) async {
    final cached = _cache[key];
    final cachedAt = _cacheAt[key];
    if (cached != null && cachedAt != null && DateTime.now().difference(cachedAt) < _cacheTtl) {
      return cached as T;
    }
    try {
      final response = await http.get(Uri.parse(url));
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
