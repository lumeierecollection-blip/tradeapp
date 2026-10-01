import 'dart:convert';

import 'package:http/http.dart' as http;

import 'signal_performance.dart';

/// Timestamped daily closes from Yahoo's chart API, used to score past signals.
/// (PriceHistoryService returns bare closes for sparklines; this keeps dates.)
///
/// Cached per symbol for [cacheTtl]. Never throws: failures return `[]`.
class HistoricalPriceService {
  static const String _base = 'https://query1.finance.yahoo.com/v8/finance/chart';
  static const Map<String, String> _headers = {'User-Agent': 'Mozilla/5.0'};
  static const Duration cacheTtl = Duration(minutes: 10);

  static final HistoricalPriceService shared = HistoricalPriceService();

  final http.Client _client;
  final Map<String, Future<List<PriceBar>>> _cache = {};
  final Map<String, DateTime> _cacheAt = {};

  HistoricalPriceService({http.Client? client}) : _client = client ?? http.Client();

  /// Daily bars covering the last [range] ('3mo', '6mo', '1y', ...), ascending.
  Future<List<PriceBar>> getDailyBars(String symbol, {String range = '1y'}) {
    final key = '$symbol|$range';
    final at = _cacheAt[key];
    final cached = _cache[key];
    if (cached != null && at != null && DateTime.now().difference(at) < cacheTtl) return cached;
    final future = _fetch(symbol, range);
    _cache[key] = future;
    _cacheAt[key] = DateTime.now();
    future.then((bars) {
      if (bars.isEmpty && identical(_cache[key], future)) {
        _cache.remove(key);
        _cacheAt.remove(key);
      }
    });
    return future;
  }

  Future<List<PriceBar>> _fetch(String symbol, String range) async {
    try {
      final uri = Uri.parse('$_base/${Uri.encodeComponent(symbol)}')
          .replace(queryParameters: {'interval': '1d', 'range': range});
      final res = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return [];
      final result = jsonDecode(res.body)['chart']?['result'];
      if (result is! List || result.isEmpty) return [];
      final stamps = result[0]['timestamp'];
      final closes = result[0]['indicators']?['quote']?[0]?['close'];
      if (stamps is! List || closes is! List) return [];
      final bars = <PriceBar>[];
      for (var i = 0; i < stamps.length && i < closes.length; i++) {
        final t = stamps[i], c = closes[i];
        if (t is num && c is num) {
          bars.add(PriceBar(DateTime.fromMillisecondsSinceEpoch(t.toInt() * 1000, isUtc: true), c.toDouble()));
        }
      }
      return bars;
    } catch (_) {
      return [];
    }
  }
}
