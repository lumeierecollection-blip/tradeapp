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
}
