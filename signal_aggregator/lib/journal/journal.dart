import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/paper_trade.dart';
import '../models/validated_signal.dart';
import '../services/storage.dart';
import 'journal_entry.dart';

/// Append-only history of what the app showed and what the user did about it.
/// Everything the review and dashboard features (Tier 2) read comes from here.
class Journal extends ChangeNotifier {
  final Storage _storage;
  final List<JournalEntry> _entries;
  final Set<String> _seenSignalIds = {};

  Journal(this._storage)
      : _entries =
            _storage.getJournalJson().map(JournalEntry.fromJson).toList() {
    _entries.sort((a, b) => a.at.compareTo(b.at));
    for (final e in _entries) {
      if (e.signalId != null) _seenSignalIds.add(e.signalId!);
    }
  }

  /// Oldest first.
  List<JournalEntry> get entries => List.unmodifiable(_entries);

  /// Records a scored signal the first time it is surfaced. Repeated refreshes
  /// of the same signal are ignored.
  void recordSignalShown(ValidatedSignal vs) {
    final sid = vs.signal.id;
    if (!_seenSignalIds.add(sid)) return;
    _append(JournalEntry(
      id: _id('sig'),
      kind: JournalKind.signalShown,
      at: DateTime.now(),
      symbol: vs.symbol,
      direction: vs.direction.label,
      probability: vs.probability,
      entry: vs.entry,
      stopLoss: vs.stopLoss,
      takeProfit: vs.takeProfit,
      summary: vs.summary,
      signalId: sid,
    ));
  }

  void recordTradeOpened(PaperTrade t) {
    _append(JournalEntry(
      id: _id('open'),
      kind: JournalKind.tradeOpened,
      at: t.openedAt,
      symbol: t.symbol,
      direction: t.direction.label,
      probability: t.probability,
      entry: t.entry,
      stopLoss: t.stopLoss,
      takeProfit: t.takeProfit,
      summary: t.reason,
      tradeId: t.id,
    ));
  }

  void recordTradeClosed(PaperTrade t) {
    _append(JournalEntry(
      id: _id('close'),
      kind: JournalKind.tradeClosed,
      at: t.closedAt ?? DateTime.now(),
      symbol: t.symbol,
      direction: t.direction.label,
      probability: t.probability,
      entry: t.entry,
      stopLoss: t.stopLoss,
      takeProfit: t.takeProfit,
      pnl: t.pnl,
      closedBy: t.closedBy,
      tradeId: t.id,
    ));
  }

  /// Replaces the mistake tags on the [JournalKind.tradeClosed] entry for
  /// [tradeId]. Used by the review flow. No-op if the entry isn't found.
  void setTags(String tradeId, List<String> tags) {
    final i = _entries.indexWhere(
        (e) => e.kind == JournalKind.tradeClosed && e.tradeId == tradeId);
    if (i < 0) return;
    _entries[i] = _entries[i].copyWith(tags: List.unmodifiable(tags));
    _persist();
    notifyListeners();
  }

  // --- queries -------------------------------------------------------------

  List<JournalEntry> bySymbol(String symbol) {
    final s = symbol.toUpperCase();
    return _entries.where((e) => e.symbol.toUpperCase() == s).toList();
  }

  List<JournalEntry> ofKind(JournalKind kind) =>
      _entries.where((e) => e.kind == kind).toList();

  /// Entries with `from <= at < to`.
  List<JournalEntry> inRange(DateTime from, DateTime to) => _entries
      .where((e) => !e.at.isBefore(from) && e.at.isBefore(to))
      .toList();

  /// Entries whose rightness falls in the 10-point bucket starting at
  /// [bucketLow] (e.g. 60 -> 60..69).
  List<JournalEntry> byProbabilityBucket(int bucketLow) {
    final low = (bucketLow ~/ 10) * 10;
    return _entries.where((e) => e.probabilityBucket == low).toList();
  }

  // --- internals ---------------------------------------------------------

  void _append(JournalEntry e) {
    _entries.add(e);
    _persist();
    notifyListeners();
  }

  void _persist() {
    _storage.setJournalJson(_entries.map((e) => e.toJson()).toList());
  }

  String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(9999)}';
}
