import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/market_snapshot.dart';
import '../../models/paper_trade.dart';
import '../../models/signal.dart';
import '../../services/market_insights.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/probability_gauge.dart';
import '../widgets/signal_card.dart';
import 'goals_screen.dart';

class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final trader = context.watch<AppState>().paperTrader;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Portfolio'),
        actions: [
          IconButton(
            tooltip: 'Refresh prices',
            onPressed: appState.isLoading ? null : appState.refresh,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: appState.refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [const Color(0xFF1B2A1E), const Color(0xFF14201F)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.buy.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PAPER BALANCE', style: TextStyle(fontSize: 12, letterSpacing: 1.2, color: Colors.white54)),
                  const SizedBox(height: 6),
                  Text(
                    '\$${trader.balance.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      StatTile(label: 'Closed P&L', value: '${trader.totalPnl >= 0 ? '+' : ''}\$${trader.totalPnl.toStringAsFixed(2)}',
                          valueColor: trader.totalPnl >= 0 ? AppTheme.buy : AppTheme.sell),
                      const SizedBox(width: 36),
                      StatTile(label: 'Win rate', value: '${trader.winRate.toStringAsFixed(0)}%'),
                      const SizedBox(width: 36),
                      StatTile(label: 'Trades', value: '${trader.trades.length}'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _GoalsLinkCard(appState: appState),
            const SizedBox(height: 24),
            const Text('Open positions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (trader.openTrades.isEmpty)
              const EmptyState(
                icon: Icons.trending_up,
                title: 'No open positions',
                message: 'Go to a signal with a strong rightness score and tap "Paper trade this signal".',
              )
            else
              ...trader.openTrades.map((t) => _OpenTradeCard(trade: t)),
            const SizedBox(height: 24),
            const Text('History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (trader.closedTrades.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No closed trades yet.',
                    style: TextStyle(fontSize: 13, color: Colors.white54)),
              )
            else
              ...trader.closedTrades.take(20).map((t) => _ClosedTradeTile(trade: t)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _GoalsLinkCard extends StatelessWidget {
  final AppState appState;
  const _GoalsLinkCard({required this.appState});

  @override
  Widget build(BuildContext context) {
    final trader = appState.paperTrader;
    final plan = appState.goalPlan;

    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final weekTrades = trader.trades.where((t) => !t.openedAt.isBefore(weekStart)).length;
    final weekPnl = trader.closedTrades
        .where((t) => t.closedAt != null && !t.closedAt!.isBefore(weekStart))
        .fold(0.0, (sum, t) => sum + (t.pnl ?? 0));
    final targetUsd = trader.startBalance * plan.weeklyTargetPct / 100;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const GoalsScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.flag_outlined, color: AppTheme.accent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekly goals · ${plan.mindset} W${plan.week}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$weekTrades/${plan.tradesPerWeek} trades · ${weekPnl >= 0 ? '+' : ''}\$${weekPnl.toStringAsFixed(2)} of \$${targetUsd.toStringAsFixed(2)} target',
                      style: const TextStyle(fontSize: 12.5, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpenTradeCard extends StatelessWidget {
  final PaperTrade trade;
  const _OpenTradeCard({required this.trade});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final price = appState.priceOf(trade.symbol);
    final pnl = trade.pnlAt(price);
    final pnlPct = trade.pnlPercentAt(price);
    final color = pnl >= 0 ? AppTheme.buy : AppTheme.sell;

    final totalRisk = (trade.takeProfit - trade.stopLoss).abs();
    final progress = totalRisk <= 0
        ? 0.0
        : ((price - trade.stopLoss) / totalRisk).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('BUY ${trade.symbol}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: trade.positionType == PositionType.conviction
                        ? AppTheme.warn.withValues(alpha: 0.18)
                        : AppTheme.accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    trade.positionType.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: trade.positionType == PositionType.conviction ? AppTheme.warn : AppTheme.accent,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${pnl >= 0 ? '+' : ''}\$${pnl.toStringAsFixed(2)} (${pnlPct >= 0 ? '+' : ''}${pnlPct.toStringAsFixed(1)}%)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.notifications_active_outlined, size: 14, color: AppTheme.accent),
                const SizedBox(width: 6),
                Text(
                  'Closes ${AppTheme.fmtClock(trade.sellAt)} · reminders at -5m, -2m, 0m',
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                StatTile(label: 'Entry', value: AppTheme.fmtPrice(trade.entry)),
                const SizedBox(width: 24),
                StatTile(label: 'Now', value: AppTheme.fmtPrice(price)),
                const SizedBox(width: 24),
                StatTile(label: 'Est. at entry', value: '${trade.probability.round()}%'),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text('Stop ${AppTheme.fmtPrice(trade.stopLoss)}', style: const TextStyle(fontSize: 12, color: Colors.white54)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor: const Color(0xFF232C3A),
                        color: progress <= 0.5 ? AppTheme.sell : AppTheme.buy,
                      ),
                    ),
                  ),
                ),
                Text('Target ${AppTheme.fmtPrice(trade.takeProfit)}', style: const TextStyle(fontSize: 12, color: Colors.white54)),
              ],
            ),
            const SizedBox(height: 8),
            _WhyMovingPanel(
              symbol: trade.symbol,
              entry: trade.entry,
              market: appState.markets[trade.symbol],
              all: appState.markets,
              signals: appState.rawSignals,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      context.read<AppState>().closeAtMarket(trade.id, price);
                    },
                    child: const Text('Close now'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      context.read<AppState>().closeTrade(trade.id, closedBy: 'target');
                    },
                    child: const Text('Take target'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WhyMovingPanel extends StatelessWidget {
  final String symbol;
  final double entry;
  final MarketSnapshot? market;
  final Map<String, MarketSnapshot> all;
  final List<Signal> signals;

  const _WhyMovingPanel({
    required this.symbol,
    required this.entry,
    required this.market,
    required this.all,
    required this.signals,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.line),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: const Icon(Icons.school_outlined, size: 19, color: AppTheme.accent),
          title: const Text(
            'Why is it moving? · Learn',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
          ),
          children: [
            ...MarketInsights.explainPosition(
              symbol: symbol,
              entry: entry,
              market: market,
              all: all,
              signals: signals,
            ).map((line) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Icon(Icons.circle, size: 5, color: AppTheme.accent),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          line,
                          style: const TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.45),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _ClosedTradeTile extends StatelessWidget {
  final PaperTrade trade;
  const _ClosedTradeTile({required this.trade});

  @override
  Widget build(BuildContext context) {
    final pnl = trade.pnl ?? 0;
    final color = pnl >= 0 ? AppTheme.buy : AppTheme.sell;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF161C26),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${trade.symbol} · ${trade.status}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    '${AppTheme.fmtPrice(trade.entry)} → ${AppTheme.fmtPrice(trade.exit ?? 0)} · ${AppTheme.timeAgo(trade.closedAt ?? trade.openedAt)}',
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                ],
              ),
            ),
            Text(
              '${pnl >= 0 ? '+' : ''}\$${pnl.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
