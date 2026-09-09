/// Spread, slippage and taker fee — the one execution-cost model shared by the
/// live paper trader and the backtester, so a paper result and a backtest of the
/// same idea are comparable rather than one being quietly rosier than the other.
///
/// Defaults are deliberately conservative: a 0.10% taker fee, 0.05% slippage and
/// a 0.05% spread (half paid on each side).
class TradingCosts {
  /// Taker fee charged on the notional of each fill.
  final double feeRate;

  /// One-directional slippage applied to every fill.
  final double slippageRate;

  /// Full bid/ask spread; half is paid entering and half exiting.
  final double spreadRate;

  const TradingCosts({
    this.feeRate = 0.001,
    this.slippageRate = 0.0005,
    this.spreadRate = 0.0005,
  });

  /// Fraction added to a buy fill and subtracted from a sell fill.
  double get friction => spreadRate / 2 + slippageRate;

  /// Price actually paid when buying at quoted [price].
  double buyFill(double price) => price * (1 + friction);

  /// Price actually received when selling at quoted [price].
  double sellFill(double price) => price * (1 - friction);

  /// Taker fee on a position worth [notional].
  double fee(double notional) => notional.abs() * feeRate;

  TradingCosts copyWith({
    double? feeRate,
    double? slippageRate,
    double? spreadRate,
  }) =>
      TradingCosts(
        feeRate: feeRate ?? this.feeRate,
        slippageRate: slippageRate ?? this.slippageRate,
        spreadRate: spreadRate ?? this.spreadRate,
      );
}
