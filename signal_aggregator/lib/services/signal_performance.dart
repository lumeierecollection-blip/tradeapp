// Scores logged model signals (signal_history.json) against realised prices.
// Pure logic, no I/O: the caller supplies daily closes per symbol.

/// One daily close. [time] is the bar's open time (UTC).
class PriceBar {
  final DateTime time;
  final double close;
  const PriceBar(this.time, this.close);
}

/// A BUY/SELL signal pulled out of the history log.
class LoggedSignal {
  final String symbol;
  final String direction; // 'BUY' | 'SELL'
  final double confidence;
  final double entryPrice;
  final DateTime generatedAt;

  const LoggedSignal({
    required this.symbol,
    required this.direction,
    required this.confidence,
    required this.entryPrice,
    required this.generatedAt,
  });

  int get sign => direction == 'BUY' ? 1 : -1;
}

enum Outcome { win, loss, pending }

class SignalResult {
  final LoggedSignal signal;
  final Outcome outcome;

  /// Signed P&L in percent (positive = the signal was right). Null while pending.
  final double? pnlPct;
  final double? exitPrice;

  const SignalResult(this.signal, this.outcome, {this.pnlPct, this.exitPrice});
}

class PerformanceSummary {
  final List<SignalResult> results;
  const PerformanceSummary(this.results);

  List<SignalResult> get _scored => results.where((r) => r.outcome != Outcome.pending).toList();
  List<SignalResult> get wins => results.where((r) => r.outcome == Outcome.win).toList();
  List<SignalResult> get losses => results.where((r) => r.outcome == Outcome.loss).toList();
  int get pending => results.where((r) => r.outcome == Outcome.pending).length;
  int get scoredCount => _scored.length;

  /// Percent of scored signals that moved in their direction; null with none scored.
  double? get winRate => scoredCount == 0 ? null : wins.length / scoredCount * 100;

  /// Mean P&L % of winners (positive) / losers (negative); null when there are none.
  double? get avgWin => _mean(wins);
  double? get avgLoss => _mean(losses);

  /// Mean P&L % across all scored signals.
  double? get avgPnl => _mean(_scored);

  static double? _mean(List<SignalResult> rs) =>
      rs.isEmpty ? null : rs.fold<double>(0, (a, r) => a + r.pnlPct!) / rs.length;
}

class SignalPerformance {
  /// Flattens the history log into BUY/SELL signals. Tolerates junk entries.
  /// HOLD, errored (price <= 0) and unparseable rows are skipped. A signal's
  /// time is its own `generated_at`, falling back to its run's `timestamp`.
  static List<LoggedSignal> parseHistory(List<dynamic> history) {
    final out = <LoggedSignal>[];
    for (final run in history) {
      if (run is! Map) continue;
      final runTime = DateTime.tryParse('${run['timestamp'] ?? ''}');
      final signals = run['signals'];
      if (signals is! List) continue;
      for (final s in signals) {
        if (s is! Map) continue;
        final direction = '${s['signal'] ?? ''}'.toUpperCase();
        final price = s['price'];
        final symbol = '${s['symbol'] ?? ''}';
        final at = DateTime.tryParse('${s['generated_at'] ?? ''}') ?? runTime;
        if ((direction != 'BUY' && direction != 'SELL') || symbol.isEmpty) continue;
        if (price is! num || price <= 0 || at == null) continue;
        final conf = s['confidence'];
        out.add(LoggedSignal(
          symbol: symbol,
          direction: direction,
          confidence: conf is num ? conf.toDouble() : 0,
          entryPrice: price.toDouble(),
          generatedAt: at.toUtc(),
        ));
      }
    }
    return out;
  }

  /// Scores [signals] at [horizon] after generation using [barsBySymbol]
  /// (ascending by time). The exit is the first *completed* daily bar dated on
  /// or after the target day; a bar dated today (UTC) is still forming, so
  /// signals that need it, or a bar that doesn't exist yet, stay pending.
  static PerformanceSummary evaluate(
    List<LoggedSignal> signals,
    Map<String, List<PriceBar>> barsBySymbol,
    Duration horizon, {
    DateTime? now,
  }) {
    final today = _day((now ?? DateTime.now()).toUtc());
    final results = <SignalResult>[];
    for (final s in signals) {
      final target = _day(s.generatedAt.add(horizon));
      final bars = barsBySymbol[s.symbol] ?? const <PriceBar>[];
      PriceBar? exit;
      for (final b in bars) {
        if (!_day(b.time).isBefore(target)) {
          exit = b;
          break;
        }
      }
      if (exit == null || !_day(exit.time).isBefore(today)) {
        results.add(SignalResult(s, Outcome.pending));
        continue;
      }
      final pnl = s.sign * (exit.close - s.entryPrice) / s.entryPrice * 100;
      results.add(SignalResult(s, pnl > 0 ? Outcome.win : Outcome.loss,
          pnlPct: pnl, exitPrice: exit.close));
    }
    return PerformanceSummary(results);
  }

  static DateTime _day(DateTime t) => DateTime.utc(t.year, t.month, t.day);
}
