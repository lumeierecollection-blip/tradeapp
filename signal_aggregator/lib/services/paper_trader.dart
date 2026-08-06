import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/paper_trade.dart';
import '../models/validated_signal.dart';
import 'storage.dart';

class PaperTrader extends ChangeNotifier {
  final Storage _storage;
  double _balance;
  final List<PaperTrade> _trades;

  PaperTrader(this._storage)
      : _balance = _storage.paperBalance,
        _trades = _storage.getTradesJson().map(PaperTrade.fromJson).toList() {
    _balance = _storage.paperBalance;
    _trades.sort((a, b) => b.openedAt.compareTo(a.openedAt));
  }

  double get balance => _balance;
  double get startBalance => _storage.startBalance;
  List<PaperTrade> get trades => List.unmodifiable(_trades);

  List<PaperTrade> get openTrades => _trades.where((t) => t.isOpen).toList();
  List<PaperTrade> get closedTrades => _trades.where((t) => !t.isOpen).toList();

  double get totalPnl => closedTrades.fold(0, (sum, t) => sum + (t.pnl ?? 0));

  int get wins => closedTrades.where((t) => (t.pnl ?? 0) > 0).length;

  double get winRate => closedTrades.isEmpty ? 0 : wins / closedTrades.length * 100;

  double get highConfidenceAccuracy {
    final high = closedTrades.where((t) => t.probability >= 65).toList();
    if (high.isEmpty) return 0;
    final won = high.where((t) => (t.pnl ?? 0) > 0).length;
    return won / high.length * 100;
  }

  double get openUnrealizedPnl {
    var sum = 0.0;
    for (final t in openTrades) {
      sum += t.pnlAt(t.entry);
    }
    return sum;
  }

  static const int convictionPerDay = 2;

  /// Wider reward target used for accumulation stacks: 3x risk instead of 1.5x.
  static const double accumulateRewardMultiple = 3.0;

  String openTrade(ValidatedSignal vs, double amount,
      {PositionType type = PositionType.accumulate}) {
    if (amount <= 0) return 'Choose an amount larger than 0.';
    if (amount > _balance) return 'Not enough paper balance.';
    if (vs.direction != Direction.buy) return 'Only BUY signals open trades.';
    if (type == PositionType.conviction && convictionUsedToday >= convictionPerDay) {
      return 'Conviction cap reached ($convictionPerDay per day). Use Accumulate for smaller stacks.';
    }

    final risk = (vs.entry - vs.stopLoss).abs();
    final target = type == PositionType.conviction
        ? vs.takeProfit
        : vs.entry + risk * accumulateRewardMultiple;

    final qty = amount / vs.entry;
    final trade = PaperTrade(
      id: 'pt-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}',
      symbol: vs.symbol,
      entry: vs.entry,
      quantity: qty,
      amount: amount,
      stopLoss: vs.stopLoss,
      takeProfit: target,
      probability: vs.probability,
      reason: vs.summary,
      openedAt: DateTime.now(),
      sellAt: vs.sellAt,
      positionType: type,
    );
    _balance -= amount;
    _trades.insert(0, trade);
    _persist();
    notifyListeners();
    return '';
  }

  /// How many conviction positions were opened today (local time).
  int get convictionUsedToday {
    final now = DateTime.now();
    return _trades
        .where((t) =>
            t.isConviction &&
            t.openedAt.year == now.year &&
            t.openedAt.month == now.month &&
            t.openedAt.day == now.day)
        .length;
  }

  void closeTrade(String id, {String? closedBy}) {
    final trade = _trades.firstWhere((t) => t.id == id, orElse: () {
      throw StateError('Trade not found');
    });
    if (!trade.isOpen) return;
    final exitPrice = trade.takeProfit >= trade.entry && closedBy == 'target'
        ? trade.takeProfit
        : trade.stopLoss <= trade.entry && closedBy == 'stop'
            ? trade.stopLoss
            : trade.entry;
    trade.exit = exitPrice;
    trade.pnl = (exitPrice - trade.entry) * trade.quantity;
    trade.closedAt = DateTime.now();
    trade.closedBy = closedBy;
    _balance += trade.amount + (trade.pnl ?? 0);
    _persist();
    notifyListeners();
  }

  void closeAtMarket(String id, double price) {
    final trade = _trades.firstWhere((t) => t.id == id);
    if (!trade.isOpen) return;
    trade.exit = price;
    trade.pnl = (price - trade.entry) * trade.quantity;
    trade.closedAt = DateTime.now();
    trade.closedBy = 'manual';
    _balance += trade.amount + (trade.pnl ?? 0);
    _persist();
    notifyListeners();
  }

  void checkStops(double Function(String symbol) currentPrice) {
    var changed = false;
    for (final trade in openTrades) {
      final price = currentPrice(trade.symbol);
      if (price <= 0) continue;
      if (price <= trade.stopLoss) {
        trade.exit = trade.stopLoss;
        trade.pnl = (trade.stopLoss - trade.entry) * trade.quantity;
        trade.closedAt = DateTime.now();
        trade.closedBy = 'stop';
        _balance += trade.amount + (trade.pnl ?? 0);
        changed = true;
      } else if (price >= trade.takeProfit) {
        trade.exit = trade.takeProfit;
        trade.pnl = (trade.takeProfit - trade.entry) * trade.quantity;
        trade.closedAt = DateTime.now();
        trade.closedBy = 'target';
        _balance += trade.amount + (trade.pnl ?? 0);
        changed = true;
      }
    }
    if (changed) {
      _persist();
      notifyListeners();
    }
  }

  Future<void> resetBalance(double amount) async {
    _balance = amount;
    await _storage.setPaperBalance(amount);
    await _storage.setStartBalance(amount);
    notifyListeners();
  }

  void _persist() {
    _storage.setPaperBalance(_balance);
    _storage.setTradesJson(_trades.map((t) => t.toJson()).toList());
  }
}
