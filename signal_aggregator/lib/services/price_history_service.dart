import 'dart:convert';

import 'package:http/http.dart' as http;

/// Daily closes from Yahoo's chart API, for sparklines and the detail chart.
///
/// Results (and in-flight requests, so parallel cards share one fetch) are
/// cached per symbol+range for [cacheTtl]. Never throws: failures return `[]`.
class PriceHistoryService {
  static const String _base = 'https://query1.finance.yahoo.com/v8/finance/chart';

  // Yahoo answers 429 to non-browser user agents.
  static const Map<String, String> _headers = {'User-Agent': 'Mozilla/5.0'};
  static const Duration cacheTtl = Duration(minutes: 5);

  /// App-wide instance so every screen shares one cache.
  static final PriceHistoryService shared = PriceHistoryService();

  final http.Client _client;
  final Map<String, Future<List<double>>> _cache = {};
  final Map<String, DateTime> _cacheAt = {};

  PriceHistoryService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<double>> getPriceHistory(String symbol, {int days = 30}) {
    final key = '$symbol|$days';
    final at = _cacheAt[key];
    final cached = _cache[key];
    if (cached != null && at != null && DateTime.now().difference(at) < cacheTtl) {
      return cached;
    }
    final future = _fetch(symbol, days);
    _cache[key] = future;
    _cacheAt[key] = DateTime.now();
    // Don't keep a failure cached for the full TTL — let the next render retry.
    future.then((closes) {
      if (closes.isEmpty && identical(_cache[key], future)) {
        _cache.remove(key);
        _cacheAt.remove(key);
      }
    });
    return future;
  }

  Future<List<double>> _fetch(String symbol, int days) async {
    try {
      final uri = Uri.parse('$_base/${Uri.encodeComponent(symbol)}')
          .replace(queryParameters: {'interval': '1d', 'range': '${days}d'});
      final res = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return [];
      final result = jsonDecode(res.body)['chart']?['result'];
      if (result is! List || result.isEmpty) return [];
      final closes = result[0]['indicators']?['quote']?[0]?['close'];
      if (closes is! List) return [];
      return closes.whereType<num>().map((c) => c.toDouble()).toList();
    } catch (_) {
      return [];
    }
  }
}
