import 'package:flutter_test/flutter_test.dart';

import 'package:signal_aggregator/models/market_snapshot.dart';
import 'package:signal_aggregator/models/signal.dart';
import 'package:signal_aggregator/models/validated_signal.dart';
import 'package:signal_aggregator/services/sentiment.dart';
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
}
