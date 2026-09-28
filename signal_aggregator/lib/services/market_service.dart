import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models/market_snapshot.dart';

/// Live market snapshots from Yahoo Finance's public chart API (no key).
///
/// Two requests per symbol: 1h bars over 5 days (RSI, ATR, support/resistance,
/// 1h/24h change, volume) and 5m bars over 1 day (5m/15m change). A 1-day range
/// of 1h bars is too short — index futures return only ~4 bars in that window.
class MarketService {
  static const String _base = 'https://query1.finance.yahoo.com/v8/finance/chart';

  // Yahoo answers 429 to non-browser user agents.
  static const Map<String, String> _headers = {'User-Agent': 'Mozilla/5.0'};

  final http.Client _client;

  MarketService({http.Client? client}) : _client = client ?? http.Client();

  /// App symbol → Yahoo ticker. Crypto keeps its bare ticker so social-signal
  /// symbol extraction and saved watchlists keep matching; everything else uses
  /// the Yahoo ticker as-is (same naming as the ML signals).
  static const Map<String, String> symbolToPair = {
    'EURUSD=X': 'EURUSD=X',
    'GBPUSD=X': 'GBPUSD=X',
    'USDJPY=X': 'USDJPY=X',
    'AUDUSD=X': 'AUDUSD=X',
    'NZDUSD=X': 'NZDUSD=X',
    'GBPJPY=X': 'GBPJPY=X',
    'EURJPY=X': 'EURJPY=X',
    'AUDJPY=X': 'AUDJPY=X',
    'USDCAD=X': 'USDCAD=X',
    'GC=F': 'GC=F',
    'SI=F': 'SI=F',
    'CL=F': 'CL=F',
    'NG=F': 'NG=F',
    'BTC': 'BTC-USD',
    'ETH': 'ETH-USD',
    'SOL': 'SOL-USD',
    'BNB': 'BNB-USD',
    '^GSPC': '^GSPC',
    '^NDX': '^NDX',
  };

  static String? toPair(String symbol) => symbolToPair[symbol.toUpperCase()];

  /// The whole supported universe — every market the app can surface and trade.
  static List<String> get allSymbols => symbolToPair.keys.toList();

  final Map<String, MarketSnapshot> _cache = {};
  final Map<String, DateTime> _cacheAt = {};
  static const Duration _cacheTtl = Duration(seconds: 20);

  Future<Map<String, MarketSnapshot>> fetchSnapshots(List<String> symbols) async {
    final results = <String, MarketSnapshot>{};
    for (final symbol in symbols) {
      final pair = toPair(symbol);
      if (pair == null) continue;
      final cached = _cache[symbol];
      final cachedAt = _cacheAt[symbol];
      if (cached != null &&
          cachedAt != null &&
          DateTime.now().difference(cachedAt) < _cacheTtl) {
        results[symbol] = cached;
        continue;
      }
      try {
        final snap = await fetchSnapshot(symbol, pair);
        _cache[symbol] = snap;
        _cacheAt[symbol] = DateTime.now();
        results[symbol] = snap;
      } catch (_) {
        // Bars failed. Try the price-only fallback; if that fails too, reuse
        // the last snapshot but flag it as stale so nothing treats it as live.
        final fallback = await _fallbackSnapshot(symbol, pair);
        final previous = _cache[symbol];
        if (fallback != null) {
          _cache[symbol] = fallback;
          _cacheAt[symbol] = DateTime.now();
          results[symbol] = fallback;
        } else if (previous != null) {
          results[symbol] = previous.copyWith(stale: true);
        }
      }
    }
    return results;
  }

  /// A degraded snapshot: real price from the chart meta, everything else
  /// neutralised. Marked stale so signals built on it can be downgraded.
  Future<MarketSnapshot?> _fallbackSnapshot(String symbol, String pair) async {
    try {
      final result = await _chart(pair, '1d', '1d');
      final price = (result['meta']?['regularMarketPrice'] as num?)?.toDouble();
      if (price == null || price <= 0) return null;
      return MarketSnapshot(
        symbol: symbol,
        price: price,
        change5m: 0,
        change15m: 0,
        change1h: 0,
        change24h: 0,
        rsi14: 50,
        volume24h: 0,
        avgVolume: 0,
        support: 0,
        resistance: 0,
        at: DateTime.now(),
        source: 'yahoo-spot',
        stale: true,
      );
    } catch (_) {
      return null;
    }
  }

  Future<MarketSnapshot> fetchSnapshot(String symbol, String pair) async {
    final candles1h = _candles(await _chart(pair, '1h', '5d'));
    if (candles1h.isEmpty) throw Exception('No 1h bars for $pair');

    // 5m bars only feed the short-horizon changes; don't lose the snapshot if
    // they're unavailable.
    var candles5m = <Candle>[];
    try {
      candles5m = _candles(await _chart(pair, '5m', '1d'));
    } catch (_) {}

    final lastPrice = candles5m.isNotEmpty ? candles5m.last.close : candles1h.last.close;
    final now = DateTime.fromMillisecondsSinceEpoch(
        max(candles1h.last.openTime, candles5m.isEmpty ? 0 : candles5m.last.openTime));

    final change5m = _changeSince(candles5m, lastPrice, now.subtract(const Duration(minutes: 5)));
    final change15m = _changeSince(candles5m, lastPrice, now.subtract(const Duration(minutes: 15)));
    final change1h = _changeSince(candles1h, lastPrice, now.subtract(const Duration(hours: 1)));
    final change24h = _changeSince(candles1h, lastPrice, now.subtract(const Duration(hours: 24)));
    final rsi14 = _rsi(candles1h, 14);

    final dayCutoff = now.subtract(const Duration(hours: 24)).millisecondsSinceEpoch;
    final day = candles1h.where((c) => c.openTime >= dayCutoff).toList();
    final window = day.isNotEmpty ? day : candles1h;
    final support = window.map((c) => c.low).reduce(min);
    final resistance = window.map((c) => c.high).reduce(max);
    final volume24h = window.map((c) => c.volume).fold(0.0, (a, b) => a + b);

    final avgVolume = candles1h.map((c) => c.volume).reduce((a, b) => a + b) / candles1h.length;
    final atrPct = _atrPct(candles1h, lastPrice);
    final recentVolumeRatio =
        candles1h.length >= 6 && avgVolume > 0
            ? candles1h.sublist(candles1h.length - 6).map((c) => c.volume).reduce((a, b) => a + b) / 6 / avgVolume
            : 1.0;

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
      atrPct: atrPct,
      recentVolumeRatio: recentVolumeRatio,
      at: DateTime.now(),
    );
  }

  /// % change from the last close at or before [since] to [price]; 0 when the
  /// bars don't reach back that far (e.g. market just opened).
  double _changeSince(List<Candle> candles, double price, DateTime since) {
    final cutoff = since.millisecondsSinceEpoch;
    Candle? ref;
    for (final c in candles) {
      if (c.openTime > cutoff) break;
      ref = c;
    }
    if (ref == null || ref.close <= 0) return 0;
    return (price - ref.close) / ref.close * 100;
  }

  /// ATR(14) on 1h candles as a % of price — how much price swings per hour.
  double _atrPct(List<Candle> candles, double price) {
    if (candles.length < 15 || price <= 0) return 0;
    var sum = 0.0;
    for (var i = candles.length - 14; i < candles.length; i++) {
      sum += candles[i].high - candles[i].low;
    }
    return sum / 14 / price * 100;
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

  /// Oldest-first candles from a chart result, skipping bars Yahoo left null.
  List<Candle> _candles(Map<String, dynamic> result) {
    final times = (result['timestamp'] as List?) ?? const [];
    final quotes = result['indicators']?['quote'];
    if (quotes is! List || quotes.isEmpty) return [];
    final q = quotes[0] as Map;
    final highs = q['high'] as List? ?? const [];
    final lows = q['low'] as List? ?? const [];
    final closes = q['close'] as List? ?? const [];
    final volumes = q['volume'] as List? ?? const [];
    final out = <Candle>[];
    for (var i = 0; i < times.length; i++) {
      if (i >= closes.length || i >= highs.length || i >= lows.length) break;
      final h = highs[i], l = lows[i], c = closes[i];
      if (h == null || l == null || c == null) continue;
      final v = i < volumes.length ? volumes[i] : null;
      out.add(Candle(
        openTime: (times[i] as num).toInt() * 1000,
        high: (h as num).toDouble(),
        low: (l as num).toDouble(),
        close: (c as num).toDouble(),
        volume: (v as num?)?.toDouble() ?? 0,
      ));
    }
    return out;
  }

  Future<Map<String, dynamic>> _chart(String pair, String interval, String range) async {
    final uri = Uri.parse('$_base/${Uri.encodeComponent(pair)}')
        .replace(queryParameters: {'interval': interval, 'range': range});
    final res = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('Yahoo ${res.statusCode} for $pair');
    }
    final result = jsonDecode(res.body)['chart']?['result'];
    if (result is! List || result.isEmpty) throw Exception('Empty chart for $pair');
    return Map<String, dynamic>.from(result[0] as Map);
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
