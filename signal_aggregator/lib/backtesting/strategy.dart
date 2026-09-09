import 'bar.dart';

/// An entry rule. [shouldEnter] sees only bars up to and including the current
/// one — the engine never hands it the future. Exits are owned by the engine
/// (stop / target / end-of-data), so a strategy only answers "enter now?".
abstract class Strategy {
  String get name;

  /// [history] is the chronological slice `bars[0..i]` (inclusive). Return true
  /// to open a position on the next bar's open.
  bool shouldEnter(List<Bar> history);
}

/// Enters on the first up-tick while RSI is at or below [oversold]. Deterministic
/// and cheap — a reasonable default for validating that a signal has any edge.
class RsiDipStrategy implements Strategy {
  final int period;
  final double oversold;

  const RsiDipStrategy({this.period = 14, this.oversold = 35});

  @override
  String get name => 'RSI dip (<= ${oversold.toStringAsFixed(0)})';

  @override
  bool shouldEnter(List<Bar> history) {
    if (history.length < period + 2) return false;
    final rsi = rsiWilder(history, period);
    final turnedUp = history.last.close > history[history.length - 2].close;
    return rsi <= oversold && turnedUp;
  }
}

/// Test helper: opens as soon as there is a next bar to fill on.
class AlwaysEnterStrategy implements Strategy {
  const AlwaysEnterStrategy();

  @override
  String get name => 'Always enter';

  @override
  bool shouldEnter(List<Bar> history) => true;
}

/// Wilder-smoothed RSI over the closes in [bars]. Returns 50 when there is not
/// enough data, 100 when there are no losses in the window.
double rsiWilder(List<Bar> bars, int period) {
  if (bars.length < period + 1) return 50;
  var gain = 0.0;
  var loss = 0.0;
  for (var i = 1; i <= period; i++) {
    final change = bars[i].close - bars[i - 1].close;
    if (change >= 0) {
      gain += change;
    } else {
      loss -= change;
    }
  }
  var avgGain = gain / period;
  var avgLoss = loss / period;
  for (var i = period + 1; i < bars.length; i++) {
    final change = bars[i].close - bars[i - 1].close;
    avgGain = (avgGain * (period - 1) + (change > 0 ? change : 0)) / period;
    avgLoss = (avgLoss * (period - 1) + (change < 0 ? -change : 0)) / period;
  }
  if (avgLoss == 0) return 100;
  final rs = avgGain / avgLoss;
  return 100 - (100 / (1 + rs));
}
