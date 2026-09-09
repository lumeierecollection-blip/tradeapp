import 'dart:math';

import 'backtest_engine.dart';

/// Everything the results screen shows, derived purely from a [BacktestResult]'s
/// trades and equity curve. No randomness, no hidden state.
class PerformanceMetrics {
  final List<BacktestTrade> trades;
  final List<EquityPoint> equityCurve;
  final double initialBalance;

  PerformanceMetrics({
    required this.trades,
    required this.equityCurve,
    required this.initialBalance,
  });

  PerformanceMetrics.of(BacktestResult r)
      : trades = r.trades,
        equityCurve = r.equityCurve,
        initialBalance = r.config.initialBalance;

  Iterable<BacktestTrade> get _wins => trades.where((t) => t.netPnl > 0);
  Iterable<BacktestTrade> get _losses => trades.where((t) => t.netPnl < 0);

  int get totalTrades => trades.length;
  int get wins => _wins.length;
  int get losses => _losses.length;

  /// Wins as a share of all trades. Break-even trades count against it.
  double get winRate => totalTrades == 0 ? 0 : wins / totalTrades * 100;

  double get netProfit => trades.fold(0.0, (s, t) => s + t.netPnl);
  double get grossProfit => _wins.fold(0.0, (s, t) => s + t.netPnl);
  double get grossLoss => _losses.fold(0.0, (s, t) => s + t.netPnl).abs();
  double get totalFees => trades.fold(0.0, (s, t) => s + t.fees);

  double get finalBalance => initialBalance + netProfit;
  double get totalReturnPct =>
      initialBalance > 0 ? netProfit / initialBalance * 100 : 0;

  /// Gross profit / gross loss. `infinity` when there are wins but no losses;
  /// `0` when there are no winning trades.
  double get profitFactor {
    if (grossLoss > 0) return grossProfit / grossLoss;
    return grossProfit > 0 ? double.infinity : 0;
  }

  double get avgWin => wins == 0 ? 0 : grossProfit / wins;

  /// Positive magnitude of the average losing trade.
  double get avgLoss => losses == 0 ? 0 : grossLoss / losses;

  /// Expected net P&L per trade, in account currency.
  double get expectancy => totalTrades == 0 ? 0 : netProfit / totalTrades;

  double get maxDrawdown {
    var peak = initialBalance;
    var worst = 0.0;
    for (final p in equityCurve) {
      if (p.equity > peak) peak = p.equity;
      final dd = peak - p.equity;
      if (dd > worst) worst = dd;
    }
    return worst;
  }

  double get maxDrawdownPct {
    var peak = initialBalance;
    var worst = 0.0;
    for (final p in equityCurve) {
      if (p.equity > peak) peak = p.equity;
      if (peak > 0) {
        final ddPct = (peak - p.equity) / peak * 100;
        if (ddPct > worst) worst = ddPct;
      }
    }
    return worst;
  }

  int get longestLosingStreak => _longestRun((t) => t.netPnl < 0);
  int get longestWinningStreak => _longestRun((t) => t.netPnl > 0);

  int _longestRun(bool Function(BacktestTrade) test) {
    var run = 0;
    var best = 0;
    for (final t in trades) {
      if (test(t)) {
        run++;
        if (run > best) best = run;
      } else {
        run = 0;
      }
    }
    return best;
  }

  /// Mean net P&L over its standard deviation, scaled by sqrt(n). A per-trade
  /// dispersion figure — NOT an annualised Sharpe ratio. Use it only to compare
  /// how noisy two strategies' returns are.
  double get perTradeSharpe {
    if (trades.length < 2) return 0;
    final rs = trades.map((t) => t.netPnl).toList();
    final mean = rs.reduce((a, b) => a + b) / rs.length;
    var variance = 0.0;
    for (final r in rs) {
      variance += (r - mean) * (r - mean);
    }
    variance /= rs.length;
    final sd = sqrt(variance);
    if (sd < 1e-12) return 0;
    return mean / sd * sqrt(rs.length);
  }

  /// Ordered label -> formatted value, for a simple results table.
  Map<String, String> table() => {
        'Trades': '$totalTrades',
        'Win rate': '${winRate.toStringAsFixed(1)}%',
        'Net P&L': netProfit.toStringAsFixed(2),
        'Return': '${totalReturnPct.toStringAsFixed(1)}%',
        'Profit factor':
            profitFactor == double.infinity ? '∞' : profitFactor.toStringAsFixed(2),
        'Expectancy / trade': expectancy.toStringAsFixed(2),
        'Avg win': avgWin.toStringAsFixed(2),
        'Avg loss': (-avgLoss).toStringAsFixed(2),
        'Max drawdown': '${maxDrawdownPct.toStringAsFixed(1)}%',
        'Longest losing streak': '$longestLosingStreak',
        'Fees paid': totalFees.toStringAsFixed(2),
      };
}
