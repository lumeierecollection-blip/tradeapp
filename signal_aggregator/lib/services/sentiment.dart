import '../models/validated_signal.dart';

class SentimentResult {
  final double bullScore;
  final double bearScore;
  final Direction direction;
  final double confidence;
  final String trigger;

  const SentimentResult({
    required this.bullScore,
    required this.bearScore,
    required this.direction,
    required this.confidence,
    required this.trigger,
  });

  static const SentimentResult neutral = SentimentResult(
    bullScore: 0,
    bearScore: 0,
    direction: Direction.wait,
    confidence: 0,
    trigger: '',
  );
}

class Sentiment {
  static const Map<String, double> _bullish = {
    'buy': 2.0,
    'buying': 1.5,
    'buy the dip': 3.0,
    'long': 1.5,
    'load': 2.0,
    'loading': 1.5,
    'accumulate': 2.5,
    'accumulation': 2.0,
    'accumulating': 2.0,
    'bull': 2.0,
    'bullish': 2.5,
    'bull run': 3.0,
    'breakout': 2.0,
    'break out': 2.0,
    'break through': 2.0,
    'pump': 2.5,
    'moon': 2.0,
    'to the moon': 3.0,
    'upside': 2.0,
    'green': 1.0,
    'upcoming rally': 2.5,
    'rally': 1.5,
    'support holding': 2.0,
    'support held': 2.0,
    'higher high': 2.0,
    'higher low': 1.5,
    'bottom': 1.5,
    'bounce': 1.5,
    'reversal up': 2.0,
    'approval': 2.0,
    'partnership': 2.0,
    'adoption': 1.5,
    'milestone': 1.5,
    'ath incoming': 2.5,
    'new high': 1.5,
    'undervalued': 1.5,
    'gem': 1.5,
    'stack': 1.5,
    'diamond hands': 1.5,
    'hodl': 1.0,
    'trend up': 2.0,
    'uptrend': 2.0,
  };

  static const Map<String, double> _bearish = {
    'sell': 2.0,
    'selling': 1.5,
    'exit': 1.5,
    'take profit': 2.0,
    'tp': 1.0,
    'short': 1.5,
    'shorting': 1.5,
    'bear': 2.0,
    'bearish': 2.5,
    'bear market': 3.0,
    'dump': 2.5,
    'crash': 2.5,
    'correction': 1.5,
    'downside': 2.0,
    'red': 1.0,
    'breakdown': 2.0,
    'break down': 2.0,
    'lower low': 2.0,
    'lower high': 1.5,
    'rejection': 2.0,
    'rejected': 2.0,
    'resistance holding': 2.0,
    'resistance held': 2.0,
    'top': 1.5,
    'overbought': 2.0,
    'bubble': 2.0,
    'scam': 2.5,
    'rug pull': 3.0,
    'rugpull': 3.0,
    'liquidation': 1.5,
    'fud': 1.5,
    'down trend': 2.0,
    'downtrend': 2.0,
    'pump and dump': 2.5,
    'pump n dump': 2.5,
    'outflow': 1.5,
    'sell the news': 2.0,
  };

  static SentimentResult analyze(String text) {
    final lower = text.toLowerCase();
    var bull = 0.0;
    var bear = 0.0;
    String trigger = '';

    _bullish.forEach((word, weight) {
      if (lower.contains(word)) {
        bull += weight;
        if (trigger.isEmpty) trigger = word;
      }
    });
    _bearish.forEach((word, weight) {
      if (lower.contains(word)) {
        bear += weight;
        if (trigger.isEmpty) trigger = word;
      }
    });

    final total = bull + bear;
    if (total < 1.5) {
      return SentimentResult.neutral;
    }

    final Direction direction;
    if (bull > bear * 1.3) {
      direction = Direction.buy;
    } else if (bear > bull * 1.3) {
      direction = Direction.sell;
    } else {
      direction = Direction.wait;
    }

    final dominance = max2(bull, bear);
    final confidence = (dominance / total).clamp(0.0, 1.0);
    return SentimentResult(
      bullScore: bull,
      bearScore: bear,
      direction: direction,
      confidence: confidence,
      trigger: trigger,
    );
  }

  static double max2(double a, double b) => a > b ? a : b;
}
