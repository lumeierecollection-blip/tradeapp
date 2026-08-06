import 'signal.dart';

enum Direction {
  buy('BUY', 'up'),
  sell('SELL', 'down'),
  wait('WAIT', 'neutral');

  final String label;
  final String bias;
  const Direction(this.label, this.bias);
}

class FactorScore {
  final String label;
  final double score;
  final String plain;
  const FactorScore({
    required this.label,
    required this.score,
    required this.plain,
  });
}

class ValidatedSignal {
  final Signal signal;
  final String symbol;
  final Direction direction;
  final double probability;
  final List<FactorScore> factors;
  final double entry;
  final double stopLoss;
  final double takeProfit;
  final String entryWindow;
  final DateTime buyAt;
  final DateTime sellAt;
  final String summary;

  const ValidatedSignal({
    required this.signal,
    required this.symbol,
    required this.direction,
    required this.probability,
    required this.factors,
    required this.entry,
    required this.stopLoss,
    required this.takeProfit,
    required this.entryWindow,
    required this.buyAt,
    required this.sellAt,
    required this.summary,
  });

  String get riskRewardText {
    final risk = (entry - stopLoss).abs();
    final reward = (takeProfit - entry).abs();
    if (risk <= 0 || reward <= 0) return '—';
    return '1 : ${(reward / risk).toStringAsFixed(1)}';
  }

  double get upsidePct {
    if (entry <= 0) return 0;
    return ((takeProfit - entry).abs() / entry) * 100;
  }

  /// The exact, data-derived moment the signal became actionable.
  DateTime get actionableAt => buyAt;

  /// How far away the sell time is from [now].
  Duration? timeUntilSell(DateTime now) {
    final d = sellAt.difference(now);
    return d.isNegative ? null : d;
  }

  /// Plain-English status of where this signal sits right now.
  String status(DateTime now) {
    if (now.isBefore(buyAt)) return 'starts at ${_clock(buyAt)}';
    if (now.isBefore(sellAt)) return 'live · sell at ${_clock(sellAt)}';
    return 'window closed';
  }

  Map<String, dynamic> toJson() => {
        'signal': signal.toJson(),
        'symbol': symbol,
        'direction': direction.name,
        'probability': probability,
        'factors': factors
            .map((f) => {'label': f.label, 'score': f.score, 'plain': f.plain})
            .toList(),
        'entry': entry,
        'stopLoss': stopLoss,
        'takeProfit': takeProfit,
        'entryWindow': entryWindow,
        'buyAt': buyAt.toIso8601String(),
        'sellAt': sellAt.toIso8601String(),
        'summary': summary,
      };

  factory ValidatedSignal.fromJson(Map<String, dynamic> json) {
    final buyAt = DateTime.tryParse(json['buyAt'] as String? ?? '');
    return ValidatedSignal(
      signal: Signal.fromJson(json['signal'] as Map<String, dynamic>),
      symbol: json['symbol'] as String,
      direction: Direction.values.firstWhere((d) => d.name == json['direction']),
      probability: (json['probability'] as num).toDouble(),
      factors: (json['factors'] as List<dynamic>? ?? [])
          .map((f) => FactorScore(
                label: (f as Map<String, dynamic>)['label'] as String,
                score: (f['score'] as num).toDouble(),
                plain: f['plain'] as String,
              ))
          .toList(),
      entry: (json['entry'] as num).toDouble(),
      stopLoss: (json['stopLoss'] as num).toDouble(),
      takeProfit: (json['takeProfit'] as num).toDouble(),
      entryWindow: json['entryWindow'] as String? ?? '',
      buyAt: buyAt ?? DateTime.now(),
      sellAt: DateTime.tryParse(json['sellAt'] as String? ?? '') ?? (buyAt ?? DateTime.now()).add(const Duration(hours: 2)),
      summary: json['summary'] as String,
    );
  }
}

String _clock(DateTime t) {
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
