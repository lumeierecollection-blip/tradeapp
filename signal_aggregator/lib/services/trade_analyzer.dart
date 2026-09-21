import '../models/paper_trade.dart';

enum TradeError { emotional, timing, risk, technical, none }

class TradeAnalyzer {
  /// Categorises a closed trade based on execution quality.
  static TradeError categorize(
    PaperTrade trade, {
    required double atrAtEntry,
    required double atrAtExit,
  }) {
    if (trade.exit == null || trade.closedAt == null) return TradeError.none;

    // Exit captured less than 30% of the intended move
    final intendedMove = (trade.takeProfit - trade.entry).abs();
    final actualMove = (trade.exit! - trade.entry).abs();
    if (intendedMove > 0 && actualMove / intendedMove < 0.30) {
      return TradeError.timing;
    }

    // Position size more than 2x recommended (using 2% risk as baseline)
    final stopDistance = (trade.entry - trade.stopLoss).abs();
    if (stopDistance > 0) {
      final recommendedQty = (trade.amount * 0.02) / stopDistance;
      if (trade.quantity > 2 * recommendedQty) {
        return TradeError.risk;
      }
    }

    // Entry more than 1x ATR away from signal price
    if (atrAtEntry > 0) {
      final deviation = (trade.entry - trade.stopLoss).abs();
      if (deviation > atrAtEntry) {
        return TradeError.technical;
      }
    }

    // Trade opened within 5 minutes of a prior loss (emotional revenge trade)
    if (trade.closedAt != null) {
      final timeSinceOpened = trade.openedAt.difference(trade.closedAt!).abs();
      if (timeSinceOpened.inMinutes < 5 && (trade.pnl ?? 0) < 0) {
        return TradeError.emotional;
      }
    }

    return TradeError.none;
  }

  /// Summarises error categories across a list of trades.
  static Map<TradeError, int> summarize(List<PaperTrade> trades) {
    final counts = <TradeError, int>{};
    for (final error in TradeError.values) {
      counts[error] = 0;
    }
    for (final trade in trades) {
      final error = categorize(trade, atrAtEntry: 0, atrAtExit: 0);
      counts[error] = (counts[error] ?? 0) + 1;
    }
    return counts;
  }

  /// Returns the most frequent non-none error, or null if none found.
  static TradeError? topMistake(List<PaperTrade> trades) {
    final summary = summarize(trades);
    summary.remove(TradeError.none);
    if (summary.isEmpty) return null;
    return summary.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }
}
