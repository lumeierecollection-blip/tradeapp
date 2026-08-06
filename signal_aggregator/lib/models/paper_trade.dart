import 'validated_signal.dart';

class PaperTrade {
  final String id;
  final String symbol;
  final double entry;
  final double quantity;
  final double amount;
  final double stopLoss;
  final double takeProfit;
  final double probability;
  final String reason;
  final DateTime openedAt;

  double? exit;
  double? pnl;
  DateTime? closedAt;
  String? closedBy;

  PaperTrade({
    required this.id,
    required this.symbol,
    required this.entry,
    required this.quantity,
    required this.amount,
    required this.stopLoss,
    required this.takeProfit,
    required this.probability,
    required this.reason,
    required this.openedAt,
    this.exit,
    this.pnl,
    this.closedAt,
    this.closedBy,
  });

  bool get isOpen => closedAt == null;

  double pnlAt(double price) => (price - entry) * quantity;

  double pnlPercentAt(double price) => amount <= 0 ? 0 : ((price - entry) / entry) * 100;

  String get status {
    if (closedBy == 'stop') return 'Stopped out';
    if (closedBy == 'target') return 'Hit target';
    return 'Open';
  }

  Direction get direction => Direction.buy;

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'entry': entry,
        'quantity': quantity,
        'amount': amount,
        'stopLoss': stopLoss,
        'takeProfit': takeProfit,
        'probability': probability,
        'reason': reason,
        'openedAt': openedAt.toIso8601String(),
        'exit': exit,
        'pnl': pnl,
        'closedAt': closedAt?.toIso8601String(),
        'closedBy': closedBy,
      };

  factory PaperTrade.fromJson(Map<String, dynamic> json) => PaperTrade(
        id: json['id'] as String,
        symbol: json['symbol'] as String,
        entry: (json['entry'] as num).toDouble(),
        quantity: (json['quantity'] as num).toDouble(),
        amount: (json['amount'] as num).toDouble(),
        stopLoss: (json['stopLoss'] as num).toDouble(),
        takeProfit: (json['takeProfit'] as num).toDouble(),
        probability: (json['probability'] as num).toDouble(),
        reason: json['reason'] as String? ?? '',
        openedAt: DateTime.parse(json['openedAt'] as String),
        exit: (json['exit'] as num?)?.toDouble(),
        pnl: (json['pnl'] as num?)?.toDouble(),
        closedAt: json['closedAt'] != null ? DateTime.parse(json['closedAt'] as String) : null,
        closedBy: json['closedBy'] as String?,
      );
}
