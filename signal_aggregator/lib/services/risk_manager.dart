class RiskManager {
  /// ATR-based position size.
  /// equity: current account equity
  /// riskPercent: e.g. 0.02 = 2% risk per trade
  /// atr: average true range of the instrument (price units)
  /// stopMultiplier: e.g. 2.5 -> stop = 2.5 * ATR
  static double positionSize({
    required double equity,
    required double riskPercent,
    required double atr,
    double stopMultiplier = 2.5,
  }) {
    if (atr <= 0) return 0;
    final stopDistance = atr * stopMultiplier;
    return (equity * riskPercent) / stopDistance;
  }

  /// Returns true if trading is allowed given today's loss.
  static bool canTradeToday({
    required double startingEquity,
    required double currentEquity,
    double maxDailyLossPercent = 0.05,
  }) {
    if (startingEquity <= 0) return false;
    final loss = (startingEquity - currentEquity) / startingEquity;
    return loss < maxDailyLossPercent;
  }

  /// Reject trades with excessive spread (in pips).
  static bool spreadOk(double spreadPips, {double maxPips = 3.0}) =>
      spreadPips <= maxPips;
}
