import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:signal_aggregator/models/signal.dart';
import 'package:signal_aggregator/models/validated_signal.dart';
import 'package:signal_aggregator/services/paper_trader.dart';
import 'package:signal_aggregator/services/storage.dart';
import 'package:signal_aggregator/trading/costs.dart';

ValidatedSignal _sig({double entry = 100, double stop = 90, double target = 130}) =>
    ValidatedSignal(
      signal: Signal(
        id: 's1',
        sourceKey: 'test',
        sourceName: 'test',
        author: 'a',
        title: 't',
        text: 'x',
        symbols: const ['BTC'],
        postedAt: DateTime.utc(2026),
        url: '',
      ),
      symbol: 'BTC',
      direction: Direction.buy,
      probability: 70,
      factors: const [],
      entry: entry,
      stopLoss: stop,
      takeProfit: target,
      entryWindow: '',
      buyAt: DateTime.utc(2026),
      sellAt: DateTime.utc(2026).add(const Duration(hours: 2)),
      summary: 'why',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const costs = TradingCosts();
  late PaperTrader trader;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'paper_balance': 1000.0,
      'start_balance': 1000.0,
    });
    trader = PaperTrader(await Storage.load());
  });

  test('entry fills above the quote; committed cash covers notional + fee', () {
    expect(trader.openTrade(_sig(entry: 100), 200), '');
    expect(trader.balance, closeTo(800, 1e-9));

    final t = trader.openTrades.single;
    expect(t.entry, closeTo(costs.buyFill(100), 1e-9));
    expect(t.quantity * t.entry * (1 + costs.feeRate), closeTo(200, 1e-6));
  });

  test('a winning close returns proceeds minus both taker fees', () {
    trader.openTrade(_sig(entry: 100, target: 130), 200);
    trader.closeTrade(trader.openTrades.single.id, closedBy: 'target');

    final t = trader.closedTrades.single;
    final exitFill = costs.sellFill(130);
    final expectedPnl = (exitFill - t.entry) * t.quantity -
        costs.fee(t.entry * t.quantity) -
        costs.fee(exitFill * t.quantity);

    expect(t.exit, closeTo(exitFill, 1e-9));
    expect(t.pnl, closeTo(expectedPnl, 1e-9));
    expect(t.pnl, greaterThan(0));
    expect(trader.balance, closeTo(1000 + expectedPnl, 1e-6));
  });

  test('checkStops closes at the stop and books a loss that includes fees', () {
    trader.openTrade(_sig(entry: 100, stop: 90), 200);
    trader.checkStops((_) => 85);

    final t = trader.closedTrades.single;
    expect(t.closedBy, 'stop');
    expect(t.exit, closeTo(costs.sellFill(90), 1e-9));
    expect(t.pnl, isNotNull);
    expect(t.pnl, lessThan(0));
    expect(trader.balance, closeTo(1000 + t.pnl!, 1e-6));
  });

  test('a round-trip with no price move loses only the friction + fees', () {
    trader.openTrade(_sig(entry: 100), 200);
    trader.closeAtMarket(trader.openTrades.single.id, 100);

    final t = trader.closedTrades.single;
    expect(t.pnl, lessThan(0));
    expect(t.pnl, greaterThan(-5)); // costs only, not a blow-up
  });

  test('closeTrade with no reason exits flat at the entry (costs only)', () {
    trader.openTrade(_sig(entry: 100), 200);
    trader.closeTrade(trader.openTrades.single.id);

    final t = trader.closedTrades.single;
    expect(t.closedBy, 'manual');
    expect(t.exit, closeTo(costs.sellFill(t.entry), 1e-9));
    expect(t.pnl, lessThan(0));
  });
}
