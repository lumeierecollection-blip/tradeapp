import 'package:flutter_test/flutter_test.dart';

import 'package:signal_aggregator/models/market_snapshot.dart';

MarketSnapshot _snap() => MarketSnapshot(
      symbol: 'BTC',
      price: 100,
      change5m: 0.2,
      change15m: 0.4,
      change1h: 1.1,
      change24h: 3.0,
      rsi14: 55,
      volume24h: 5000,
      avgVolume: 4000,
      support: 95,
      resistance: 110,
      atrPct: 1.8,
      recentVolumeRatio: 1.3,
      at: DateTime.utc(2026),
    );

void main() {
  test('defaults: fresh, binance source', () {
    final s = _snap();
    expect(s.stale, isFalse);
    expect(s.source, 'binance');
  });

  test('copyWith flips stale/source and leaves the rest', () {
    final s = _snap().copyWith(stale: true, source: 'yahoo');
    expect(s.stale, isTrue);
    expect(s.source, 'yahoo');
    expect(s.price, 100);
    expect(s.rsi14, 55);
    expect(s.at, DateTime.utc(2026));
  });

  test('source and stale round-trip through JSON', () {
    final s = _snap().copyWith(stale: true, source: 'yahoo');
    final r = MarketSnapshot.fromJson(s.toJson());
    expect(r.stale, isTrue);
    expect(r.source, 'yahoo');
    expect(r.price, s.price);
  });

  test('old JSON without the fields loads as fresh/binance', () {
    final json = _snap().toJson()
      ..remove('stale')
      ..remove('source');
    final r = MarketSnapshot.fromJson(json);
    expect(r.stale, isFalse);
    expect(r.source, 'binance');
  });
}
