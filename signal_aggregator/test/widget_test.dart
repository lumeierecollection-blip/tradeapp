import 'package:flutter_test/flutter_test.dart';

import 'package:signal_aggregator/models/market_snapshot.dart';
import 'package:signal_aggregator/models/signal.dart';
import 'package:signal_aggregator/models/validated_signal.dart';
import 'package:signal_aggregator/services/market_insights.dart';
import 'package:signal_aggregator/services/sentiment.dart';
import 'package:signal_aggregator/services/sources/market_pulse_source.dart';
import 'package:signal_aggregator/services/symbols.dart';
import 'package:signal_aggregator/services/validator.dart';

void main() {
  group('Sentiment', () {
    test('detects bullish talk', () {
      final result = Sentiment.analyze('BTC looks bullish, buy the dip and accumulate');
      expect(result.direction, Direction.buy);
      expect(result.confidence, greaterThan(0.5));
    });

    test('detects bearish talk', () {
      final result = Sentiment.analyze('ETH is overbought, sell before the dump');
      expect(result.direction, Direction.sell);
    });

    test('neutral when no keywords', () {
      final result = Sentiment.analyze('the weather is nice today');
      expect(result.direction, Direction.wait);
    });
  });

  group('Symbols', () {
    test('extracts tickers and names', () {
      final found = Symbols.extract('Bitcoin and ETH look strong today');
      expect(found, containsAll(['BTC', 'ETH']));
    });

    test('does not match partial words', () {
      final found = Symbols.extract('lets go shopping near the dogs park');
      expect(found, isNot(contains('DOGE')));
    });
  });

  group('Validator', () {
    MarketSnapshot makeMarket() => MarketSnapshot(
          symbol: 'BTC',
          price: 60000,
          change5m: 0.4,
          change15m: 0.9,
          change1h: 2.0,
          change24h: 5.0,
          rsi14: 55,
          volume24h: 1500,
          avgVolume: 1000,
          support: 59000,
          resistance: 62000,
          at: DateTime.now(),
        );

    Signal makeSignal() => Signal(
          id: 't1',
          sourceKey: 'reddit',
          sourceName: 'r/Bitcoin',
          author: 'u/test',
          title: 'BTC bullish',
          text: 'Buy bitcoin, the market looks strong.',
          symbols: const ['BTC'],
          postedAt: DateTime.now(),
          url: '',
        );

    test('returns a buy signal when market agrees', () {
      final result = Validator().validate(makeSignal(), {'BTC': makeMarket()});
      expect(result, isNotNull);
      expect(result!.symbol, 'BTC');
      expect(result.direction, Direction.buy);
      expect(result.probability, inInclusiveRange(5, 95));
      expect(result.factors.length, 5);
    });

    test('computes exact buy and sell times', () {
      final now = DateTime(2026, 8, 6, 14, 30, 12);
      final result = Validator().validate(makeSignal(), {'BTC': makeMarket()}, now: now);
      expect(result, isNotNull);
      final vs = result!;
      expect(vs.buyAt, DateTime(2026, 8, 6, 14, 31));
      expect(vs.sellAt.isAfter(vs.buyAt), isTrue);
      expect(vs.sellAt.difference(vs.buyAt).inMinutes, greaterThanOrEqualTo(45));
      expect(vs.sellAt.difference(vs.buyAt).inMinutes, lessThanOrEqualTo(8 * 60));
      expect(vs.status(DateTime(2026, 8, 6, 14, 31)), startsWith('live'));
      expect(vs.status(DateTime(2026, 8, 6, 18, 0)), 'window closed');
    });

    test('take profit is above entry for buys', () {
      final result = Validator().validate(makeSignal(), {'BTC': makeMarket()});
      expect(result!.takeProfit, greaterThan(result.entry));
      expect(result.stopLoss, lessThan(result.entry));
    });
  });

  group('Market pulse', () {
    MarketSnapshot makeMarket() => MarketSnapshot(
          symbol: 'LINK',
          price: 10.0,
          change5m: 0.1,
          change15m: -0.3,
          change1h: -1.2,
          change24h: -4.0,
          rsi14: 35,
          volume24h: 2000,
          avgVolume: 1000,
          support: 9.8,
          resistance: 11.0,
          atrPct: 1.5,
          recentVolumeRatio: 1.8,
          at: DateTime.now(),
        );

    test('emits a buy-dip signal for an oversold coin near support', () {
      final signals = const MarketPulseSource().generate({'LINK': makeMarket()});
      expect(signals, hasLength(1));
      expect(signals.first.symbols, ['LINK']);
      expect(signals.first.sourceKey, 'pulse');
      final validated = Validator().validate(signals.first, {'LINK': makeMarket()});
      expect(validated, isNotNull);
      expect(validated!.direction, Direction.buy);
    });
  });

  group('MarketSnapshot', () {
    test('round-trips the new precision fields', () {
      final snap = MarketSnapshot(
        symbol: 'SOL',
        price: 140.0,
        change5m: 0.2,
        change15m: 0.4,
        change1h: 1.1,
        change24h: 3.0,
        rsi14: 58,
        volume24h: 5000,
        avgVolume: 4000,
        support: 135.0,
        resistance: 150.0,
        atrPct: 2.3,
        recentVolumeRatio: 1.4,
        at: DateTime.now(),
      );
      final restored = MarketSnapshot.fromJson(snap.toJson());
      expect(restored.atrPct, snap.atrPct);
      expect(restored.recentVolumeRatio, snap.recentVolumeRatio);
    });

    test('explains why a losing position is down', () {
      final snap = MarketSnapshot(
        symbol: 'ETH',
        price: 3100.0,
        change5m: -0.6,
        change15m: -1.0,
        change1h: -2.2,
        change24h: -5.0,
        rsi14: 32,
        volume24h: 9000,
        avgVolume: 6000,
        support: 3050.0,
        resistance: 3300.0,
        atrPct: 1.8,
        recentVolumeRatio: 1.5,
        at: DateTime.now(),
      );
      final btc = MarketSnapshot(
        symbol: 'BTC',
        price: 60000.0,
        change5m: -0.5,
        change15m: -0.8,
        change1h: -1.9,
        change24h: -4.5,
        rsi14: 34,
        volume24h: 1000,
        avgVolume: 800,
        support: 58000.0,
        resistance: 63000.0,
        atrPct: 1.2,
        recentVolumeRatio: 1.3,
        at: DateTime.now(),
      );
      final lines = MarketInsights.explainPosition(
        symbol: 'ETH',
        entry: 3200.0,
        market: snap,
        all: {'BTC': btc, 'ETH': snap},
        signals: const [],
      );
      expect(lines.join('\n'), contains('down'));
      expect(lines.join('\n'), contains('broad market'));
      expect(lines.join('\n'), contains('RSI'));
    });
  });
}
