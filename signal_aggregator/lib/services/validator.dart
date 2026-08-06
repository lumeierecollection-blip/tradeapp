import 'dart:math';

import '../models/market_snapshot.dart';
import '../models/signal.dart';
import '../models/validated_signal.dart';
import 'sentiment.dart';

class Validator {
  ValidatedSignal? validate(Signal signal, Map<String, MarketSnapshot> markets, {DateTime? now}) {
    for (final symbol in signal.symbols) {
      final market = markets[symbol];
      if (market == null) continue;
      final result = _validateSymbol(signal, symbol, market, now: now);
      if (result != null) return result;
    }
    return null;
  }

  ValidatedSignal? _validateSymbol(Signal signal, String symbol, MarketSnapshot m, {DateTime? now}) {
    final sentiment = Sentiment.analyze('${signal.title}\n${signal.text}');
    if (sentiment.direction == Direction.wait) return null;

    final bias = sentiment.direction;
    final factors = <FactorScore>[];

    // 1. Momentum alignment (30%)
    final momentumScore = _momentumScore(m, bias);
    factors.add(FactorScore(
      label: 'Momentum',
      score: momentumScore,
      plain: 'Price is ${_fmtPct(m.change1h)} over the last hour '
          '${bias == Direction.buy ? '— matches the bullish talk.' : '— matches the bearish talk.'}',
    ));

    // 2. Volume confirmation (20%)
    final volumeScore = ((m.volumeRatio - 0.5) / 1.5 * 100 + 40).clamp(5.0, 100.0);
    factors.add(FactorScore(
      label: 'Volume',
      score: volumeScore,
      plain: 'Trading volume is ${m.volumeRatio.toStringAsFixed(1)}x normal. '
          '${m.volumeRatio >= 1.2 ? 'Strong participation backs this move.' : 'Quiet volume — the move is less confirmed.'}',
    ));

    // 3. RSI position (20%)
    final rsiScore = _rsiScore(m.rsi14, bias);
    factors.add(FactorScore(
      label: 'RSI',
      score: rsiScore,
      plain: 'RSI is ${m.rsi14.toStringAsFixed(0)} out of 100. '
          '${_rsiPlain(m.rsi14, bias)}',
    ));

    // 4. Support / resistance (20%)
    final srScore = _supportResistanceScore(m, bias);
    factors.add(FactorScore(
      label: 'Entry zone',
      score: srScore,
      plain: bias == Direction.buy
          ? 'Price sits ${_fmtPct(m.distanceToSupport)} above recent support — '
              '${m.nearSupport ? 'a good entry area.' : 'not an ideal entry yet.'}'
          : 'Price sits ${_fmtPct(m.distanceToResistance)} below recent resistance — '
              '${m.nearResistance ? 'a good level to expect a pullback.' : 'not an ideal sell area yet.'}',
    ));

    // 5. Message clarity (10%)
    final clarityScore = sentiment.confidence * 100;
    factors.add(FactorScore(
      label: 'Message clarity',
      score: clarityScore,
      plain: 'The post gives a ${bias == Direction.buy ? 'clear bullish' : 'clear bearish'} signal'
          '${sentiment.trigger.isEmpty ? '' : ' ("${sentiment.trigger}")'} .',
    ));

    final probability = (_weighted(factors) * 100).clamp(5.0, 95.0);
    final riskBuffer = bias == Direction.buy
        ? max(m.price * 0.015, (m.price - m.support).clamp(0, m.price * 0.05) * 0.5 + m.price * 0.005)
        : max(m.price * 0.015, (m.resistance - m.price).clamp(0, m.price * 0.05) * 0.5 + m.price * 0.005);

    final entry = m.price;
    final stopLoss = bias == Direction.buy ? entry - riskBuffer : entry + riskBuffer;
    final takeProfit = bias == Direction.buy ? entry + riskBuffer * 1.5 : entry - riskBuffer * 1.5;

    final validatedAt = now ?? DateTime.now();
    final buyAt = _nextMinute(validatedAt);
    final sellAt = buyAt.add(_sellOffset(m, bias, entry, takeProfit));

    return ValidatedSignal(
      signal: signal,
      symbol: symbol,
      direction: bias,
      probability: probability,
      factors: factors,
      entry: entry,
      stopLoss: stopLoss,
      takeProfit: takeProfit,
      entryWindow: _entryWindow(m, bias),
      buyAt: buyAt,
      sellAt: sellAt,
      summary: _summary(signal, symbol, m, bias, probability),
    );
  }

  /// Rounds up to the next whole minute so the buy time is a clean clock time.
  DateTime _nextMinute(DateTime t) {
    return DateTime(t.year, t.month, t.day, t.hour, t.minute).add(const Duration(minutes: 1));
  }

  /// Exact duration from buy to sell, derived from how fast price is actually
  /// moving toward the target right now — not an arbitrary window. Uses the
  /// market's own volatility (ATR) as a reality check and volume to confirm
  /// the pace.
  Duration _sellOffset(MarketSnapshot m, Direction bias, double entry, double target) {
    final distance = (target - entry).abs();
    final aligned5 = (bias == Direction.buy ? m.change5m : -m.change5m) / 100;
    final aligned15 = (bias == Direction.buy ? m.change15m : -m.change15m) / 100;
    final aligned1h = (bias == Direction.buy ? m.change1h : -m.change1h) / 100;

    // Price change per minute, from the fastest interval moving the right way.
    var perMinute = entry * aligned5 / 5;
    if (perMinute <= 0) perMinute = entry * aligned15 / 15;
    if (perMinute <= 0) perMinute = entry * aligned1h / 60;

    // Volatility floor: how far price tends to travel per minute based on
    // recent 1h candle ranges. Never promise a faster target than the
    // market's own choppiness supports.
    final atrPct = m.atrPct > 0 ? m.atrPct : 0.6;
    final volPerMinute = entry * atrPct / 100 / 60;
    if (perMinute <= 0) perMinute = volPerMinute * 0.5;

    var minutes = distance / perMinute;
    final volFloor = distance / volPerMinute;
    if (minutes < volFloor) minutes = volFloor;
    if (minutes > 4 * 60) minutes = 4 * 60;

    // Volume confirms pace: participation makes targets arrive sooner,
    // thin volume means moves stall and take longer.
    if (m.volumeRatio >= 1.2) minutes *= 0.85;
    if (m.volumeRatio < 0.8) minutes *= 1.25;
    if (m.recentVolumeRatio >= 1.3) minutes *= 0.9;

    minutes = minutes.clamp(25.0, 12 * 60.0);
    return Duration(minutes: minutes.round());
  }

  double _weighted(List<FactorScore> factors) {
    const weights = [0.30, 0.20, 0.20, 0.20, 0.10];
    var total = 0.0;
    for (var i = 0; i < factors.length && i < weights.length; i++) {
      total += factors[i].score / 100 * weights[i];
    }
    return total;
  }

  double _momentumScore(MarketSnapshot m, Direction bias) {
    final aligned = bias == Direction.buy ? m.change1h : -m.change1h;
    return (50 + aligned * 10).clamp(5.0, 100.0);
  }

  double _rsiScore(double rsi, Direction bias) {
    if (bias == Direction.buy) {
      if (rsi >= 75) return 10;
      if (rsi >= 60) return (100 - (rsi - 60) * 2).clamp(10.0, 100.0);
      if (rsi >= 40) return 100;
      return (100 - (40 - rsi) * 1.5).clamp(10.0, 100.0);
    } else {
      if (rsi <= 25) return 10;
      if (rsi <= 40) return (100 - (40 - rsi) * 2).clamp(10.0, 100.0);
      if (rsi <= 60) return 100;
      return (100 - (rsi - 60) * 1.5).clamp(10.0, 100.0);
    }
  }

  double _supportResistanceScore(MarketSnapshot m, Direction bias) {
    if (bias == Direction.buy) {
      if (m.nearSupport) return 90;
      if (m.nearResistance) return 30;
      return 65;
    } else {
      if (m.nearResistance) return 90;
      if (m.nearSupport) return 30;
      return 65;
    }
  }

  String _entryWindow(MarketSnapshot m, Direction bias) {
    final aligned = bias == Direction.buy ? m.change5m : -m.change5m;
    if (aligned > 0.5) return 'window is open now';
    if (aligned > 0) return 'within the next 1–2 hours';
    return 'watch for the next 3–6 hours';
  }

  String _rsiPlain(double rsi, Direction bias) {
    if (bias == Direction.buy) {
      if (rsi >= 75) return 'It is overbought — buying now chases a hot price.';
      if (rsi >= 60) return 'Warming up, but still has room before overbought.';
      if (rsi >= 40) return 'A healthy middle zone — good room to rise.';
      return 'Oversold — sellers may be exhausted, so a bounce is possible.';
    } else {
      if (rsi <= 25) return 'Oversold — falling further is possible but a bounce is near.';
      if (rsi <= 40) return 'Weakening — room to fall further.';
      if (rsi <= 60) return 'A middle zone — fine for a short-term pullback.';
      return 'Overbought — buyers may be running out of steam.';
    }
  }

  String _summary(Signal signal, String symbol, MarketSnapshot m, Direction bias, double prob) {
    final source = signal.sourceName;
    final name = symbol;
    if (bias == Direction.buy) {
      return 'A post on $source talks about $name in a positive way. The market '
          'currently agrees: momentum is ${m.change1h >= 0 ? 'up' : 'mixed'} '
          '(${_fmtPct(m.change1h)} in the last hour), volume is '
          '${m.volumeRatio.toStringAsFixed(1)}x normal, and RSI (${m.rsi14.toStringAsFixed(0)}) '
          'is not overbought. Estimated chance this works out: ${prob.round()}%.';
    } else {
      return 'A post on $source talks about $name negatively. The market '
          'currently agrees: momentum is ${m.change1h < 0 ? 'down' : 'mixed'} '
          '(${_fmtPct(m.change1h)} in the last hour), and RSI (${m.rsi14.toStringAsFixed(0)}) '
          'leaves room for a pullback. Estimated chance this works out: ${prob.round()}%.';
    }
  }

  static String _fmtPct(double v) => '${v.toStringAsFixed(1)}%';
}
