import '../models/market_snapshot.dart';
import '../models/signal.dart';

/// Turns live market data into plain-English explanations of why a position
/// is currently winning or losing. Built for learning: it names the broad
/// market, the technical drivers and the recent chatter behind the move.
class MarketInsights {
  static List<String> explainPosition({
    required String symbol,
    required double entry,
    required MarketSnapshot? market,
    required Map<String, MarketSnapshot> all,
    required List<Signal> signals,
  }) {
    final lines = <String>[];
    final m = market;
    if (m == null) {
      lines.add('No live price data for $symbol right now — pull to refresh.');
      return lines;
    }

    final move = (m.price - entry) / entry * 100;
    if (move.abs() < 0.05) {
      lines.add('$symbol is basically flat vs your entry (${_pct(move)}). '
          'The market is waiting for a fresh catalyst.');
    } else {
      lines.add('Your position is ${move >= 0 ? 'up' : 'down'} ${_pct(move.abs())} '
          'vs entry — ${_verdict(move)}.');
    }

    // Broad market context: is this move $symbol-specific or the whole market?
    final btc = all['BTC'];
    if (btc != null && btc.symbol != symbol) {
      final btcMove = btc.change24h;
      final symMove = m.change24h;
      if (btcMove.abs() >= 0.3 && symMove.abs() >= 0.3 && (symMove >= 0) == (btcMove >= 0)) {
        final ratio = symMove.abs() / btcMove.abs();
        if (ratio < 1.6) {
          lines.add('This move tracks the broad market — BTC is ${_pct(btcMove)} over 24h, '
              'so most of $symbol\'s move is market-wide pressure, not news about $symbol itself.');
        } else {
          lines.add('This move is ${ratio.toStringAsFixed(1)}x stronger than BTC (${_pct(btcMove)}), '
              'so the extra push is specific to $symbol, not the whole market.');
        }
      } else if (symMove.abs() >= 0.3) {
        lines.add('$symbol is moving against the broad market (BTC is ${_pct(btcMove)}) — '
            'this is a $symbol-specific move, so watch for news or flows on $symbol.');
      }
    }

    // Technical readout.
    lines.add('Momentum: ${_pct(m.change1h)} over the last hour'
        '${m.change5m.abs() >= 0.1 ? ' (${_pct(m.change5m)} in the last 5 minutes)' : ''}.');

    if (m.volumeRatio >= 1.3) {
      lines.add('Volume is ${m.volumeRatio.toStringAsFixed(1)}x normal — the move has real '
          'participation behind it.');
    } else if (m.volumeRatio < 0.8) {
      lines.add('Volume is only ${m.volumeRatio.toStringAsFixed(1)}x normal — moves on thin '
          'volume are easier to reverse.');
    }

    lines.add(_rsiLine(m.rsi14));

    if (m.nearSupport) {
      lines.add('Price is pressing $symbol\'s recent support — a break extends losses, '
          'a hold often brings a bounce.');
    }
    if (m.nearResistance) {
      lines.add('Price is pressing $symbol\'s recent resistance — a break could accelerate '
          'gains, a rejection usually pulls back.');
    }

    // Recent chatter that may explain the move.
    final chatter = signals
        .where((s) => s.symbols.contains(symbol) && s.sourceKey != 'pulse')
        .toList()
      ..sort((a, b) => b.postedAt.compareTo(a.postedAt));
    if (chatter.isNotEmpty) {
      for (final s in chatter.take(2)) {
        final t = s.title.isNotEmpty
            ? s.title
            : (s.text.length > 80 ? '${s.text.substring(0, 80)}…' : s.text);
        lines.add('Recent chatter (${s.sourceName}): “$t”');
      }
    }

    return lines;
  }

  static String _verdict(double move) {
    if (move >= 0) return 'momentum favors your trade right now';
    return 'the market is currently moving against your entry';
  }

  static String _rsiLine(double rsi) {
    if (rsi >= 70) {
      return 'RSI is ${rsi.toStringAsFixed(0)} — overbought: gains may be near exhaustion '
          'and pullbacks often follow.';
    }
    if (rsi <= 30) {
      return 'RSI is ${rsi.toStringAsFixed(0)} — oversold: sellers look exhausted, '
          'so a bounce often follows.';
    }
    return 'RSI is ${rsi.toStringAsFixed(0)} — a middle zone with room to run.';
  }

  static String _pct(double v) => '${v.toStringAsFixed(1)}%';
}
