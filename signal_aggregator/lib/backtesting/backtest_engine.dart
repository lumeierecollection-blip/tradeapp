import 'dart:math';

import 'bar.dart';
import 'strategy.dart';

/// Trading costs and risk knobs. Defaults are deliberately conservative so a
/// backtest under-promises rather than over-promises.
class BacktestConfig {
  final double initialBalance;

  /// Stop distance below the entry fill, as a fraction (0.05 = 5%).
  final double stopLossPct;

  /// Target distance above the entry fill, as a fraction (0.10 = 10%).
  final double takeProfitPct;

  /// Fraction of current cash risked down to the stop on each trade.
  final double riskPerTradePct;

  /// Taker fee charged on notional, each side (0.001 = 0.10%).
  final double feeRate;

  /// One-directional slippage applied to every fill (0.0005 = 0.05%).
  final double slippageRate;

  /// Full bid/ask spread; half is paid on each side (0.0005 = 0.05%).
  final double spreadRate;

  const BacktestConfig({
    this.initialBalance = 500,
    this.stopLossPct = 0.05,
    this.takeProfitPct = 0.10,
    this.riskPerTradePct = 0.02,
    this.feeRate = 0.001,
    this.slippageRate = 0.0005,
    this.spreadRate = 0.0005,
  });

  /// Fraction added to a buy fill / subtracted from a sell fill.
  double get friction => spreadRate / 2 + slippageRate;

  BacktestConfig copyWith({
    double? initialBalance,
    double? stopLossPct,
    double? takeProfitPct,
    double? riskPerTradePct,
    double? feeRate,
    double? slippageRate,
    double? spreadRate,
  }) =>
      BacktestConfig(
        initialBalance: initialBalance ?? this.initialBalance,
        stopLossPct: stopLossPct ?? this.stopLossPct,
        takeProfitPct: takeProfitPct ?? this.takeProfitPct,
        riskPerTradePct: riskPerTradePct ?? this.riskPerTradePct,
        feeRate: feeRate ?? this.feeRate,
        slippageRate: slippageRate ?? this.slippageRate,
        spreadRate: spreadRate ?? this.spreadRate,
      );
}

enum ExitReason {
  stop('Stopped out'),
  target('Hit target'),
  endOfData('Closed at end');

  final String label;
  const ExitReason(this.label);
}

/// A single completed round-trip. Prices already include friction; [fees] is the
/// taker fee for both sides combined.
class BacktestTrade {
  final DateTime entryTime;
  final double entryPrice;
  final DateTime exitTime;
  final double exitPrice;
  final double quantity;
  final double fees;
  final ExitReason reason;

  const BacktestTrade({
    required this.entryTime,
    required this.entryPrice,
    required this.exitTime,
    required this.exitPrice,
    required this.quantity,
    required this.fees,
    required this.reason,
  });

  double get grossPnl => (exitPrice - entryPrice) * quantity;
  double get netPnl => grossPnl - fees;
  bool get isWin => netPnl > 0;
  double get notional => entryPrice * quantity;
  double get returnPct => notional > 0 ? netPnl / notional * 100 : 0;
  Duration get holdTime => exitTime.difference(entryTime);
}

class EquityPoint {
  final DateTime time;
  final double equity;
  const EquityPoint(this.time, this.equity);
}

class BacktestResult {
  final String strategyName;
  final BacktestConfig config;
  final List<BacktestTrade> trades;
  final List<EquityPoint> equityCurve;
  final int barsProcessed;

  const BacktestResult({
    required this.strategyName,
    required this.config,
    required this.trades,
    required this.equityCurve,
    required this.barsProcessed,
  });

  double get finalEquity =>
      equityCurve.isEmpty ? config.initialBalance : equityCurve.last.equity;
}

/// Deterministic, event-ordered backtest over [bars] (chronological ascending).
///
/// Rules:
///  * the entry decision is taken on the close of bar `i` using only `bars[0..i]`;
///  * the fill happens on the open of bar `i+1` — never the signal bar;
///  * stop / target are checked against each later bar's low / high, and if both
///    sit inside a bar's range the stop is assumed to fill first (pessimistic);
///  * every fill pays spread, slippage and the taker fee;
///  * one position at a time, long only.
BacktestResult runBacktest({
  required List<Bar> bars,
  required Strategy strategy,
  BacktestConfig config = const BacktestConfig(),
}) {
  final trades = <BacktestTrade>[];
  final equityCurve = <EquityPoint>[];
  var cash = config.initialBalance;

  var inPosition = false;
  var entryTime = DateTime.fromMillisecondsSinceEpoch(0);
  var entryPrice = 0.0;
  var qty = 0.0;
  var stopPrice = 0.0;
  var targetPrice = 0.0;
  var entryFee = 0.0;

  for (var i = 0; i < bars.length; i++) {
    final bar = bars[i];

    if (inPosition) {
      double? rawExit;
      ExitReason? reason;
      if (bar.low <= stopPrice) {
        rawExit = stopPrice;
        reason = ExitReason.stop;
      } else if (bar.high >= targetPrice) {
        rawExit = targetPrice;
        reason = ExitReason.target;
      }
      if (rawExit != null) {
        final exitFill = rawExit * (1 - config.friction);
        final exitFee = exitFill * qty * config.feeRate;
        trades.add(BacktestTrade(
          entryTime: entryTime,
          entryPrice: entryPrice,
          exitTime: bar.time,
          exitPrice: exitFill,
          quantity: qty,
          fees: entryFee + exitFee,
          reason: reason!,
        ));
        cash += exitFill * qty - exitFee;
        inPosition = false;
      }
    }

    equityCurve.add(
      EquityPoint(bar.time, inPosition ? cash + qty * bar.close : cash),
    );

    if (!inPosition && i + 1 < bars.length) {
      if (strategy.shouldEnter(bars.sublist(0, i + 1))) {
        final fill = bars[i + 1].open * (1 + config.friction);
        final stop = fill * (1 - config.stopLossPct);
        final riskPerUnit = fill - stop;
        if (riskPerUnit > 0) {
          final wantQty = cash * config.riskPerTradePct / riskPerUnit;
          final maxQty = cash / (fill * (1 + config.feeRate));
          final q = min(wantQty, maxQty);
          if (q > 0) {
            final fee = fill * q * config.feeRate;
            cash -= fill * q + fee;
            inPosition = true;
            entryTime = bars[i + 1].time;
            entryPrice = fill;
            qty = q;
            stopPrice = stop;
            targetPrice = fill * (1 + config.takeProfitPct);
            entryFee = fee;
          }
        }
      }
    }
  }

  if (inPosition && bars.isNotEmpty) {
    final last = bars.last;
    final exitFill = last.close * (1 - config.friction);
    final exitFee = exitFill * qty * config.feeRate;
    trades.add(BacktestTrade(
      entryTime: entryTime,
      entryPrice: entryPrice,
      exitTime: last.time,
      exitPrice: exitFill,
      quantity: qty,
      fees: entryFee + exitFee,
      reason: ExitReason.endOfData,
    ));
    cash += exitFill * qty - exitFee;
    equityCurve[equityCurve.length - 1] = EquityPoint(last.time, cash);
  }

  return BacktestResult(
    strategyName: strategy.name,
    config: config,
    trades: trades,
    equityCurve: equityCurve,
    barsProcessed: bars.length,
  );
}
