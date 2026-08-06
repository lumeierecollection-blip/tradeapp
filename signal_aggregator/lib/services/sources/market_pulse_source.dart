import '../../models/market_snapshot.dart';
import '../../models/signal.dart';
import 'signal_source.dart';

/// Generates signals from pure market structure — momentum, volume and RSI —
/// across the whole supported universe. This is what lets coins with no
/// social chatter still surface a trade, instead of only Bitcoin showing up.
class MarketPulseSource implements SignalSource {
  const MarketPulseSource();

  @override
  String get key => 'pulse';

  @override
  String get name => 'Market pulse';

  @override
  bool get requiresSetup => false;

  /// Plain source API returns nothing; use [generate] with live markets.
  @override
  Future<List<Signal>> fetch() async => const [];

  List<Signal> generate(Map<String, MarketSnapshot> markets) {
    final signals = <Signal>[];
    final now = DateTime.now();
    for (final snapshot in markets.values) {
      final setup = _setup(snapshot);
      if (setup == null) continue;
      signals.add(Signal(
        id: 'pulse-${snapshot.symbol}-${now.millisecondsSinceEpoch}',
        sourceKey: key,
        sourceName: name,
        author: '',
        title: setup.$1,
        text: setup.$2,
        symbols: [snapshot.symbol],
        postedAt: now,
        url: '',
      ));
    }
    return signals;
  }

  (String, String)? _setup(MarketSnapshot m) {
    final push = m.change5m;
    final drift = m.change1h;
    final vol = m.volumeRatio;

    // Buy the dip: pulled back hard toward support, buyers stepping in.
    if (drift < -0.4 && m.rsi14 < 45 && m.nearSupport && vol > 1.0) {
      return (
        'Market pulse: ${m.symbol} pullback buy setup',
        'Bullish setup. ${m.symbol} pulled back ${_pct(drift)} over the last hour toward support '
            '(${_fmtPrice(m.support)}) with volume at ${vol.toStringAsFixed(1)}x normal. '
            'RSI (${m.rsi14.toStringAsFixed(0)}) is getting oversold, so sellers look tired. '
            'Buy the dip, accumulate with a stop below support, expect upside to ${_fmtPrice(m.resistance)}.',
      );
    }

    // Momentum breakout: strong move with real volume, not near resistance.
    if (drift > 0.3 && vol > 1.5 && m.rsi14 < 70 && !m.nearResistance) {
      return (
        'Market pulse: ${m.symbol} breakout setup',
        'Bullish setup. ${m.symbol} is breaking out with volume at ${vol.toStringAsFixed(1)}x normal '
            'and momentum of ${_pct(drift)} in the last hour. RSI (${m.rsi14.toStringAsFixed(0)}) still has '
            'room before overbought. Buy on strength, stop below the breakout level, '
            'target the next resistance at ${_fmtPrice(m.resistance)}.',
      );
    }

    // Overbought rejection: parabolic into resistance, buyers exhausted.
    if (drift > 0.5 && m.rsi14 > 62 && m.nearResistance && vol > 1.0) {
      return (
        'Market pulse: ${m.symbol} rejection setup',
        'Bearish setup. ${m.symbol} rallied ${_pct(drift)} and is now hitting resistance '
            '(${_fmtPrice(m.resistance)}) with RSI (${m.rsi14.toStringAsFixed(0)}) overbought. '
            'Buyers look exhausted — expect a downside pullback and a correction. '
            'Take profit on longs, or short with a stop above resistance.',
      );
    }

    // Continuation breakdown: heavy volume selling with room below.
    if (drift < -0.3 && push < -0.3 && vol > 1.5 && m.rsi14 > 50) {
      return (
        'Market pulse: ${m.symbol} breakdown setup',
        'Bearish setup. ${m.symbol} is breaking down with volume at ${vol.toStringAsFixed(1)}x normal '
            'and downside momentum building (${_pct(drift)} in the last hour). '
            'Expect lower prices toward ${_fmtPrice(m.support)} — avoid longs and stay out of the way.',
      );
    }

    return null;
  }

  static String _pct(double v) => '${v.toStringAsFixed(1)}%';

  static String _fmtPrice(double v) =>
      v >= 1000 ? v.toStringAsFixed(0) : v >= 1 ? v.toStringAsFixed(4) : v.toStringAsExponential(2);
}
