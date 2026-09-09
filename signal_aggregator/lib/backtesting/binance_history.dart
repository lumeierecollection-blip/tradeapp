import 'dart:convert';

import 'package:http/http.dart' as http;

import 'bar.dart';

/// Read-only historical OHLCV from Binance's public REST API — the same source
/// the live app already uses, so a backtest runs on the same data a signal saw.
/// No API key.
class BinanceHistory {
  static const _base = 'https://api.binance.com';

  final http.Client _client;

  BinanceHistory({http.Client? client}) : _client = client ?? http.Client();

  /// [symbol] is a bare ticker like `BTC` (mapped to `BTCUSDT`). [interval] is
  /// a Binance kline interval (`1h`, `4h`, `1d`, …). [limit] is clamped to
  /// Binance's 1..1000 range. Bars come back oldest-first.
  Future<List<Bar>> fetch({
    required String symbol,
    String interval = '1h',
    int limit = 500,
  }) async {
    final uri = Uri.parse('$_base/api/v3/klines').replace(queryParameters: {
      'symbol': _pair(symbol),
      'interval': interval,
      'limit': '${limit.clamp(1, 1000)}',
    });

    final res = await _client.get(uri).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw BinanceHistoryException('Binance ${res.statusCode}: ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! List) {
      throw BinanceHistoryException('Unexpected klines payload');
    }
    return decoded.whereType<List>().map(Bar.fromKline).toList(growable: false);
  }

  String _pair(String symbol) {
    final s = symbol.trim().toUpperCase();
    return s.endsWith('USDT') ? s : '${s}USDT';
  }

  void dispose() => _client.close();
}

class BinanceHistoryException implements Exception {
  final String message;
  BinanceHistoryException(this.message);
  @override
  String toString() => 'BinanceHistoryException: $message';
}
