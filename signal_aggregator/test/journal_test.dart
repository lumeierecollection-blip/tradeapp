import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:signal_aggregator/journal/journal.dart';
import 'package:signal_aggregator/journal/journal_entry.dart';
import 'package:signal_aggregator/models/paper_trade.dart';
import 'package:signal_aggregator/models/signal.dart';
import 'package:signal_aggregator/models/validated_signal.dart';
import 'package:signal_aggregator/services/storage.dart';

ValidatedSignal _sig(String id, {String symbol = 'BTC', double prob = 72}) =>
    ValidatedSignal(
      signal: Signal(
        id: id,
        sourceKey: 'k',
        sourceName: 'n',
        author: 'a',
        title: 't',
        text: 'x',
        symbols: [symbol],
        postedAt: DateTime.utc(2026),
        url: '',
      ),
      symbol: symbol,
      direction: Direction.buy,
      probability: prob,
      factors: const [],
      entry: 100,
      stopLoss: 90,
      takeProfit: 130,
      entryWindow: '',
      buyAt: DateTime.utc(2026),
      sellAt: DateTime.utc(2026).add(const Duration(hours: 1)),
      summary: 'why',
    );

PaperTrade _trade(String id,
        {String symbol = 'BTC', double? pnl, String? closedBy, DateTime? closedAt}) =>
    PaperTrade(
      id: id,
      symbol: symbol,
      entry: 100,
      quantity: 1,
      amount: 100,
      stopLoss: 90,
      takeProfit: 130,
      probability: 72,
      reason: 'why',
      openedAt: DateTime.utc(2026, 1, 1),
      sellAt: DateTime.utc(2026, 1, 1, 2),
      pnl: pnl,
      closedBy: closedBy,
      closedAt: closedAt,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Storage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await Storage.load();
  });

  test('records a signal once, ignoring repeats of the same id', () {
    final j = Journal(storage);
    j.recordSignalShown(_sig('s1'));
    j.recordSignalShown(_sig('s1'));
    j.recordSignalShown(_sig('s2'));
    expect(j.ofKind(JournalKind.signalShown), hasLength(2));
  });

  test('persists across reloads and rebuilds the dedup set', () {
    final j1 = Journal(storage);
    j1.recordSignalShown(_sig('s1'));
    j1.recordTradeOpened(_trade('t1'));
    j1.recordTradeClosed(
        _trade('t1', pnl: 12.5, closedBy: 'target', closedAt: DateTime.utc(2026, 1, 2)));

    final j2 = Journal(storage);
    expect(j2.entries, hasLength(3));
    final closed = j2.ofKind(JournalKind.tradeClosed).single;
    expect(closed.pnl, 12.5);
    expect(closed.closedBy, 'target');
    expect(closed.tradeId, 't1');

    j2.recordSignalShown(_sig('s1'));
    expect(j2.ofKind(JournalKind.signalShown), hasLength(1));
  });

  test('queries by symbol, range and probability bucket', () {
    final j = Journal(storage);
    j.recordSignalShown(_sig('s1'));
    j.recordSignalShown(_sig('s2', symbol: 'ETH', prob: 64));
    j.recordSignalShown(_sig('s3', prob: 55));

    expect(j.bySymbol('btc'), hasLength(2));
    expect(j.byProbabilityBucket(70), hasLength(1));
    expect(j.byProbabilityBucket(60), hasLength(1));
    expect(j.byProbabilityBucket(50), hasLength(1));

    final now = DateTime.now();
    expect(
      j.inRange(now.subtract(const Duration(minutes: 1)), now.add(const Duration(minutes: 1))),
      hasLength(3),
    );
    expect(
      j.inRange(now.add(const Duration(days: 1)), now.add(const Duration(days: 2))),
      isEmpty,
    );
  });

  test('setTags updates the closed-trade entry and survives reload', () {
    final j1 = Journal(storage);
    j1.recordTradeClosed(
        _trade('t9', pnl: -4, closedBy: 'stop', closedAt: DateTime.utc(2026, 2, 2)));
    j1.setTags('t9', const ['early-entry', 'oversized']);

    final j2 = Journal(storage);
    expect(j2.ofKind(JournalKind.tradeClosed).single.tags,
        const ['early-entry', 'oversized']);
  });

  test('tagStats aggregates count, wins and pnl per tag, most-used first', () {
    final j = Journal(storage);
    j.recordTradeClosed(
        _trade('a', pnl: 10, closedBy: 'target', closedAt: DateTime.utc(2026, 3, 1)));
    j.recordTradeClosed(
        _trade('b', pnl: -6, closedBy: 'stop', closedAt: DateTime.utc(2026, 3, 2)));
    j.recordTradeClosed(
        _trade('c', pnl: -3, closedBy: 'stop', closedAt: DateTime.utc(2026, 3, 3)));
    j.recordTradeClosed(
        _trade('d', pnl: 5, closedBy: 'target', closedAt: DateTime.utc(2026, 3, 4)));

    j.setTags('a', const ['oversized']);
    j.setTags('b', const ['oversized', 'early-entry']);
    j.setTags('c', const ['early-entry']);
    j.setTags('d', const ['oversized']);

    final ordered = j.tagStats();
    expect(ordered.map((s) => s.tag).toList(), ['oversized', 'early-entry']);

    final stats = {for (final s in ordered) s.tag: s};
    expect(stats['oversized']!.trades, 3);
    expect(stats['oversized']!.wins, 2);
    expect(stats['oversized']!.totalPnl, closeTo(9, 1e-9)); // 10 - 6 + 5

    expect(stats['early-entry']!.trades, 2);
    expect(stats['early-entry']!.wins, 0);
    expect(stats['early-entry']!.winRate, 0);
    expect(stats['early-entry']!.totalPnl, closeTo(-9, 1e-9)); // -6 - 3
  });

  test('calibration groups closed trades by rightness bucket', () {
    final j = Journal(storage);
    // needs the probability carried on the trade -> use _tradeWithProb
    j.recordTradeClosed(_tradeP('a', prob: 74, pnl: 5, closedAt: DateTime.utc(2026, 4, 1)));
    j.recordTradeClosed(_tradeP('b', prob: 71, pnl: -2, closedAt: DateTime.utc(2026, 4, 2)));
    j.recordTradeClosed(_tradeP('c', prob: 63, pnl: 4, closedAt: DateTime.utc(2026, 4, 3)));

    final rows = j.calibration();
    expect(rows.map((r) => r.bucketLow).toList(), [60, 70]); // ascending

    final b70 = rows.firstWhere((r) => r.bucketLow == 70);
    expect(b70.label, '70-79%');
    expect(b70.trades, 2);
    expect(b70.wins, 1);
    expect(b70.winRate, 50);
    expect(b70.netPnl, closeTo(3, 1e-9)); // 5 - 2
  });

  test('symbolPerformance aggregates per coin, most-traded first', () {
    final j = Journal(storage);
    j.recordTradeClosed(_tradeP('a', symbol: 'BTC', pnl: 5, closedAt: DateTime.utc(2026, 5, 1)));
    j.recordTradeClosed(_tradeP('b', symbol: 'BTC', pnl: -3, closedAt: DateTime.utc(2026, 5, 2)));
    j.recordTradeClosed(_tradeP('c', symbol: 'ETH', pnl: 8, closedAt: DateTime.utc(2026, 5, 3)));

    final rows = j.symbolPerformance();
    expect(rows.map((r) => r.symbol).toList(), ['BTC', 'ETH']);
    expect(rows.first.trades, 2);
    expect(rows.first.wins, 1);
    expect(rows.first.netPnl, closeTo(2, 1e-9));
  });
}

PaperTrade _tradeP(String id,
        {String symbol = 'BTC', double prob = 72, double? pnl, DateTime? closedAt}) =>
    PaperTrade(
      id: id,
      symbol: symbol,
      entry: 100,
      quantity: 1,
      amount: 100,
      stopLoss: 90,
      takeProfit: 130,
      probability: prob,
      reason: 'why',
      openedAt: DateTime.utc(2026, 1, 1),
      sellAt: DateTime.utc(2026, 1, 1, 2),
      pnl: pnl,
      closedBy: (pnl ?? 0) >= 0 ? 'target' : 'stop',
      closedAt: closedAt,
    );
