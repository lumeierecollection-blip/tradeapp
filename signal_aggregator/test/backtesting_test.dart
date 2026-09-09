import 'package:flutter_test/flutter_test.dart';

import 'package:signal_aggregator/backtesting/backtest_engine.dart';
import 'package:signal_aggregator/backtesting/bar.dart';
import 'package:signal_aggregator/backtesting/performance_metrics.dart';
import 'package:signal_aggregator/backtesting/strategy.dart';

/// Strategy driven by an explicit predicate, for exact control in tests.
class _PredicateStrategy implements Strategy {
  final bool Function(List<Bar>) predicate;
  const _PredicateStrategy(this.predicate);
  @override
  String get name => 'predicate';
  @override
  bool shouldEnter(List<Bar> history) => predicate(history);
}

Bar _bar(int minute, double open, double high, double low, double close) => Bar(
      time: DateTime.utc(2026, 1, 1).add(Duration(minutes: minute)),
      open: open,
      high: high,
      low: low,
      close: close,
      volume: 1,
    );

const _cfg = BacktestConfig(); // defaults: 500 / 5% stop / 10% target / 0.075% friction

void main() {
  group('runBacktest', () {
    test('no bars and single bar produce no trades', () {
      expect(runBacktest(bars: const [], strategy: const AlwaysEnterStrategy()).trades, isEmpty);

      final one = runBacktest(bars: [_bar(0, 100, 100, 100, 100)], strategy: const AlwaysEnterStrategy());
      expect(one.trades, isEmpty);
      expect(one.equityCurve.single.equity, 500);
      expect(one.finalEquity, 500);
    });

    test('a signal on the last bar never fills (no next open)', () {
      final bars = [_bar(0, 100, 100, 100, 100), _bar(1, 100, 100, 100, 100)];
      // only enter once history covers both bars, i.e. on the final bar
      final r = runBacktest(
        bars: bars,
        strategy: _PredicateStrategy((h) => h.length == 2),
      );
      expect(r.trades, isEmpty);
    });

    test('entry fills on the NEXT bar open, not the signal bar close', () {
      final bars = [
        _bar(0, 50, 50, 50, 50), // signal decided here; close is 50
        _bar(1, 100, 105, 98, 100), // fill must use this open (100), not 50
        _bar(2, 100, 120, 99, 110), // target hit
      ];
      final r = runBacktest(bars: bars, strategy: const AlwaysEnterStrategy(), config: _cfg);
      expect(r.trades, hasLength(1));
      expect(r.trades.first.entryPrice, closeTo(100 * 1.00075, 1e-6));
    });

    test('winning trade: exit at target minus friction, fees on both sides', () {
      final bars = [
        _bar(0, 100, 100, 100, 100),
        _bar(1, 100, 101, 99.5, 100.5),
        _bar(2, 105, 112, 104, 111), // high 112 >= target 110.0825
      ];
      final r = runBacktest(bars: bars, strategy: const AlwaysEnterStrategy(), config: _cfg);
      expect(r.trades, hasLength(1));
      final t = r.trades.first;
      expect(t.reason, ExitReason.target);
      expect(t.isWin, isTrue);
      expect(t.entryPrice, closeTo(100.075, 1e-6));
      expect(t.exitPrice, closeTo(110.0825 * (1 - 0.00075), 1e-6));
      expect(t.fees, greaterThan(0));
      expect(t.netPnl, closeTo(t.grossPnl - t.fees, 1e-9));
      expect(r.finalEquity, closeTo(500 + t.netPnl, 1e-6));
    });

    test('losing trade: stop fills at the stop price', () {
      final bars = [
        _bar(0, 100, 100, 100, 100),
        _bar(1, 100, 100.5, 99, 99.2),
        _bar(2, 98, 98.5, 94, 95), // low 94 <= stop 95.07125
      ];
      final r = runBacktest(bars: bars, strategy: const AlwaysEnterStrategy(), config: _cfg);
      expect(r.trades, hasLength(1));
      final t = r.trades.first;
      expect(t.reason, ExitReason.stop);
      expect(t.isWin, isFalse);
      expect(t.netPnl, lessThan(0));
      expect(t.exitPrice, closeTo(100.075 * 0.95 * (1 - 0.00075), 1e-6));
    });

    test('when a bar spans both stop and target, the stop is assumed first', () {
      final bars = [
        _bar(0, 100, 100, 100, 100),
        _bar(1, 100, 100, 100, 100),
        _bar(2, 100, 130, 80, 100), // range covers stop 95.07 AND target 110.08
      ];
      final r = runBacktest(bars: bars, strategy: const AlwaysEnterStrategy(), config: _cfg);
      expect(r.trades.single.reason, ExitReason.stop);
    });

    test('an open position is closed at the last bar close (endOfData)', () {
      final bars = [
        _bar(0, 100, 100, 100, 100),
        _bar(1, 100, 101, 99, 100),
        _bar(2, 100, 101, 99, 100), // never reaches +-5/10%
      ];
      final r = runBacktest(bars: bars, strategy: const AlwaysEnterStrategy(), config: _cfg);
      expect(r.trades, hasLength(1));
      expect(r.trades.single.reason, ExitReason.endOfData);
      // last equity point reflects realised cash, not a mark-to-market guess
      expect(r.finalEquity, closeTo(500 + r.trades.single.netPnl, 1e-6));
    });

    test('position size risks ~riskPerTradePct of cash down to the stop', () {
      final bars = [
        _bar(0, 100, 100, 100, 100),
        _bar(1, 100, 101, 99.5, 100.5),
        _bar(2, 105, 112, 104, 111),
      ];
      final r = runBacktest(bars: bars, strategy: const AlwaysEnterStrategy(), config: _cfg);
      final t = r.trades.first;
      final riskToStop = (t.entryPrice - t.entryPrice * 0.95) * t.quantity;
      expect(riskToStop, closeTo(500 * 0.02, 0.05));
    });
  });

  group('RsiDipStrategy', () {
    test('does not fire while there is too little history', () {
      final bars = List.generate(5, (i) => _bar(i, 100, 100, 100, 100));
      expect(const RsiDipStrategy().shouldEnter(bars), isFalse);
    });

    test('fires on the first up-tick after a sustained sell-off', () {
      // 20 down bars, then one up bar -> RSI deep, last close > prior close
      final bars = <Bar>[];
      var price = 200.0;
      for (var i = 0; i < 20; i++) {
        final next = price - 5;
        bars.add(_bar(i, price, price, next, next));
        price = next;
      }
      bars.add(_bar(20, price, price + 3, price, price + 3)); // the up-tick
      expect(const RsiDipStrategy().shouldEnter(bars), isTrue);
    });
  });

  group('PerformanceMetrics', () {
    BacktestTrade trade(double exit, {double fees = 0}) => BacktestTrade(
          entryTime: DateTime.utc(2026),
          entryPrice: 100,
          exitTime: DateTime.utc(2026).add(const Duration(hours: 1)),
          exitPrice: exit,
          quantity: 1,
          fees: fees,
          reason: ExitReason.target,
        );

    test('aggregates wins, losses, factor, expectancy and streaks', () {
      // +10, -4, +6  ->  2 wins / 1 loss
      final m = PerformanceMetrics(
        trades: [trade(110), trade(96), trade(106)],
        equityCurve: [
          EquityPoint(DateTime.utc(2026, 1, 1), 100),
          EquityPoint(DateTime.utc(2026, 1, 2), 110),
          EquityPoint(DateTime.utc(2026, 1, 3), 106),
          EquityPoint(DateTime.utc(2026, 1, 4), 112),
        ],
        initialBalance: 100,
      );

      expect(m.totalTrades, 3);
      expect(m.wins, 2);
      expect(m.losses, 1);
      expect(m.winRate, closeTo(66.67, 0.01));
      expect(m.grossProfit, closeTo(16, 1e-9));
      expect(m.grossLoss, closeTo(4, 1e-9));
      expect(m.profitFactor, closeTo(4, 1e-9));
      expect(m.expectancy, closeTo(4, 1e-9));
      expect(m.avgWin, closeTo(8, 1e-9));
      expect(m.avgLoss, closeTo(4, 1e-9));
      expect(m.longestLosingStreak, 1);
      expect(m.maxDrawdown, closeTo(4, 1e-9)); // 110 -> 106
      expect(m.maxDrawdownPct, closeTo(4 / 110 * 100, 1e-9));
    });

    test('profit factor is infinite with wins and no losses, zero with none', () {
      final allWin = PerformanceMetrics(
        trades: [trade(110), trade(105)],
        equityCurve: const [],
        initialBalance: 100,
      );
      expect(allWin.profitFactor, double.infinity);

      final noTrades = PerformanceMetrics(
        trades: const [],
        equityCurve: const [],
        initialBalance: 100,
      );
      expect(noTrades.profitFactor, 0);
      expect(noTrades.winRate, 0);
      expect(noTrades.expectancy, 0);
    });
  });
}
