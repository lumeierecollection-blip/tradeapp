import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models/market_snapshot.dart';

class MarketService {
  static const String _base = 'https://api.binance.com';
  final http.Client _client = http.Client();

  static const Map<String, String> symbolToPair = {
    'BTC': 'BTCUSDT',
    'ETH': 'ETHUSDT',
    'SOL': 'SOLUSDT',
    'BNB': 'BNBUSDT',
    'XRP': 'XRPUSDT',
    'ADA': 'ADAUSDT',
    'DOGE': 'DOGEUSDT',
    'AVAX': 'AVAXUSDT',
    'LINK': 'LINKUSDT',
    'DOT': 'DOTUSDT',
    'MATIC': 'MATICUSDT',
    'LTC': 'LTCUSDT',
    'UNI': 'UNIUSDT',
    'ARB': 'ARBUSDT',
    'OP': 'OPUSDT',
    'SHIB': 'SHIBUSDT',
    'TRX': 'TRXUSDT',
    'NEAR': 'NEARUSDT',
    'APT': 'APTUSDT',
    'FIL': 'FILUSDT',
  };

  static String? toPair(String symbol) => symbolToPair[symbol.toUpperCase()];

  Future<Map<String, MarketSnapshot>> fetchSnapshots(List<String> symbols) async {
    final results = <String, MarketSnapshot>{};
    for (final symbol in symbols) {
      final pair = toPair(symbol);
      if (pair == null) continue;
      try {
        results[symbol] = await fetchSnapshot(symbol, pair);
      } catch (_) {
        // Skip coins we cannot get data for.
      }
    }
    return results;
  }

  Future<MarketSnapshot> fetchSnapshot(String symbol, String pair) async {
    final ticker = await _get('/api/v3/ticker/24hr', {'symbol': pair});
    final lastPrice = double.parse(ticker['lastPrice'].toString());
    final change24h = double.parse(ticker['priceChangePercent'].toString());
    final volume24h = double.parse(ticker['volume'].toString());

    final candles5m = await _fetchKlines(pair, '5m', 3);
    final change5m = _percentChange(candles5m);
    final candles15m = await _fetchKlines(pair, '15m', 3);
    final change15m = _percentChange(candles15m);

    final candles1h = await _fetchKlines(pair, '1h', 96);
    final change1h = _percentChange(candles1h);
    final rsi14 = _rsi(candles1h, 14);

    final window = candles1h.length >= 24 ? candles1h.sublist(candles1h.length - 24) : candles1h;
    final highs = window.map((c) => c.high).toList();
    final lows = window.map((c) => c.low).toList();
    final support = lows.reduce(min);
    final resistance = highs.reduce(max);

    final avgVolume = candles1h.isEmpty ? 1.0 : candles1h.map((c) => c.volume).reduce((a, b) => a + b) / candles1h.length;

    return MarketSnapshot(
      symbol: symbol,
      price: lastPrice,
      change5m: change5m,
      change15m: change15m,
      change1h: change1h,
      change24h: change24h,
      rsi14: rsi14,
      volume24h: volume24h,
      avgVolume: avgVolume,
      support: support,
      resistance: resistance,
      at: DateTime.now(),
    );
  }

  double _percentChange(List<Candle> candles) {
    if (candles.length < 2) return 0;
    final first = candles.first;
    final last = candles.last;
    if (first.close <= 0) return 0;
    return (last.close - first.close) / first.close * 100;
  }

  Future<List<Candle>> _fetchKlines(String pair, String interval, int limit) async {
    final data = await _get('/api/v3/klines', {
      'symbol': pair,
      'interval': interval,
      'limit': '$limit',
    });
    if (data is! List) return [];
    return data.map((k) {
      final row = k as List;
      return Candle(
        openTime: (row[0] as num).toInt(),
        high: double.parse(row[2].toString()),
        low: double.parse(row[3].toString()),
        close: double.parse(row[4].toString()),
        volume: double.parse(row[5].toString()),
      );
    }).toList();
  }

  double _rsi(List<Candle> candles, int period) {
    if (candles.length < period + 1) return 50;
    var gainSum = 0.0;
    var lossSum = 0.0;
    for (var i = 1; i <= period; i++) {
      final change = candles[i].close - candles[i - 1].close;
      if (change >= 0) {
        gainSum += change;
      } else {
        lossSum -= change;
      }
    }
    var avgGain = gainSum / period;
    var avgLoss = lossSum / period;
    for (var i = period + 1; i < candles.length; i++) {
      final change = candles[i].close - candles[i - 1].close;
      avgGain = (avgGain * (period - 1) + (change > 0 ? change : 0)) / period;
      avgLoss = (avgLoss * (period - 1) + (change < 0 ? -change : 0)) / period;
    }
    if (avgLoss == 0) return 100;
    final rs = avgGain / avgLoss;
    return 100 - (100 / (1 + rs));
  }

  Future<dynamic> _get(String path, Map<String, String> query) async {
    final uri = Uri.parse('$_base$path').replace(queryParameters: query);
    final res = await _client.get(uri).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('Market API ${res.statusCode}: ${res.body}');
    }
    return jsonDecode(res.body);
  }

  void dispose() => _client.close();
}

class Candle {
  final int openTime;
  final double high;
  final double low;
  final double close;
  final double volume;
  const Candle({
    required this.openTime,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });
}
