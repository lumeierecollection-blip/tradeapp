/// What a [JournalEntry] records.
enum JournalKind {
  signalShown,
  tradeOpened,
  tradeClosed;

  static JournalKind fromName(String? name) =>
      JournalKind.values.asNameMap()[name] ?? JournalKind.signalShown;
}

/// One append-only line in the trade journal. Signals that were surfaced and
/// paper trades that were opened / closed all land here, so later analysis has
/// a single ordered history to read.
class JournalEntry {
  final String id;
  final JournalKind kind;
  final DateTime at;
  final String symbol;

  /// 'BUY' / 'SELL' / 'WAIT' — the signal or trade direction.
  final String direction;

  /// 0..100 rightness score, when the entry came from a scored signal.
  final double? probability;

  final double? entry;
  final double? stopLoss;
  final double? takeProfit;

  /// Plain-English reason shown to the user at the time.
  final String? summary;

  /// Links [JournalKind.tradeOpened] / [JournalKind.tradeClosed] to a PaperTrade.
  final String? tradeId;

  /// The source Signal's id — set on [JournalKind.signalShown] so the same
  /// signal is only journalled once.
  final String? signalId;

  /// Realised P&L — set on [JournalKind.tradeClosed].
  final double? pnl;

  /// 'stop' / 'target' / 'manual' — set on [JournalKind.tradeClosed].
  final String? closedBy;

  /// Mistake tags. Populated later by the review flow (Tier 2a).
  final List<String> tags;

  const JournalEntry({
    required this.id,
    required this.kind,
    required this.at,
    required this.symbol,
    this.direction = 'WAIT',
    this.probability,
    this.entry,
    this.stopLoss,
    this.takeProfit,
    this.summary,
    this.tradeId,
    this.signalId,
    this.pnl,
    this.closedBy,
    this.tags = const [],
  });

  /// Lower edge of the 10-point rightness bucket this entry falls in
  /// (e.g. 63.0 -> 60), or null when there is no probability.
  int? get probabilityBucket {
    final p = probability;
    return p == null ? null : (p ~/ 10) * 10;
  }

  JournalEntry copyWith({List<String>? tags}) => JournalEntry(
        id: id,
        kind: kind,
        at: at,
        symbol: symbol,
        direction: direction,
        probability: probability,
        entry: entry,
        stopLoss: stopLoss,
        takeProfit: takeProfit,
        summary: summary,
        tradeId: tradeId,
        signalId: signalId,
        pnl: pnl,
        closedBy: closedBy,
        tags: tags ?? this.tags,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'at': at.toIso8601String(),
        'symbol': symbol,
        'direction': direction,
        'probability': probability,
        'entry': entry,
        'stopLoss': stopLoss,
        'takeProfit': takeProfit,
        'summary': summary,
        'tradeId': tradeId,
        'signalId': signalId,
        'pnl': pnl,
        'closedBy': closedBy,
        'tags': tags,
      };

  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
        id: json['id'] as String,
        kind: JournalKind.fromName(json['kind'] as String?),
        at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
        symbol: json['symbol'] as String? ?? '',
        direction: json['direction'] as String? ?? 'WAIT',
        probability: (json['probability'] as num?)?.toDouble(),
        entry: (json['entry'] as num?)?.toDouble(),
        stopLoss: (json['stopLoss'] as num?)?.toDouble(),
        takeProfit: (json['takeProfit'] as num?)?.toDouble(),
        summary: json['summary'] as String?,
        tradeId: json['tradeId'] as String?,
        signalId: json['signalId'] as String?,
        pnl: (json['pnl'] as num?)?.toDouble(),
        closedBy: json['closedBy'] as String?,
        tags: (json['tags'] as List<dynamic>? ?? const [])
            .map((t) => t.toString())
            .toList(),
      );
}
