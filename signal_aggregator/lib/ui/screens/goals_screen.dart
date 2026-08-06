import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/goal_plan.dart';
import '../../models/paper_trade.dart';
import '../../state/app_state.dart';
import '../theme.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final trader = appState.paperTrader;
    final plan = appState.goalPlan;

    final todayTrades = trader.trades.where((t) => _isToday(t.openedAt)).length;
    final weekTrades = trader.trades.where((t) => _isThisWeek(t.openedAt)).length;
    final weekPnl = trader.closedTrades
        .where((t) => t.closedAt != null && _isThisWeek(t.closedAt!))
        .fold(0.0, (sum, t) => sum + (t.pnl ?? 0));
    final weekLoss = trader.closedTrades
        .where((t) => t.closedAt != null && _isThisWeek(t.closedAt!) && (t.pnl ?? 0) < 0)
        .fold(0.0, (sum, t) => sum + (t.pnl ?? 0))
        .abs();
    final weekAccuracy = _weekAccuracy(trader.closedTrades);
    final lossLimitUsd = trader.startBalance * plan.weeklyLossLimitPct / 100;
    final targetUsd = trader.startBalance * plan.weeklyTargetPct / 100;
    final riskUsd = trader.balance * plan.riskPerTradePct / 100;

    final targetHit = weekPnl >= targetUsd;
    final lossReached = weekLoss >= lossLimitUsd;

    return Scaffold(
      appBar: AppBar(title: const Text('Weekly goals')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _PhaseCard(appState: appState),
          const SizedBox(height: 16),
          const Text('Pick your plan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'Realistic', label: Text('Realistic')),
                      ButtonSegment(value: 'Optimistic', label: Text('Optimistic')),
                    ],
                    selected: {plan.mindset},
                    onSelectionChanged: (s) {
                      appState.setGoalPlan(
                        _planFor(context, s.first, plan.week).id,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 1, label: Text('Week 1')),
                      ButtonSegment(value: 2, label: Text('Week 2')),
                    ],
                    selected: {plan.week},
                    onSelectionChanged: (s) {
                      appState.setGoalPlan(
                        _planFor(context, plan.mindset, s.first).id,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${plan.mindset} · Week ${plan.week}',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(plan.summary, style: const TextStyle(fontSize: 13.5, color: Color(0xFFC3CAD6), height: 1.5)),
                  const SizedBox(height: 16),
                  _ProgressRow(
                    label: 'Trades today',
                    value: todayTrades.toDouble(),
                    max: plan.tradesPerDay.toDouble(),
                    hint: 'buy up to ${plan.tradesPerDay} a day · close each before the next',
                    exceeded: todayTrades > plan.tradesPerDay,
                  ),
                  const SizedBox(height: 14),
                  _ProgressRow(
                    label: 'Trades this week',
                    value: weekTrades.toDouble(),
                    max: plan.tradesPerWeek.toDouble(),
                    hint: '${plan.tradesPerWeek} max · each trade = 1 buy + 1 sell',
                    exceeded: weekTrades > plan.tradesPerWeek,
                  ),
                  const SizedBox(height: 14),
                  _ProgressRow(
                    label: 'Weekly profit',
                    value: weekPnl,
                    max: targetUsd,
                    money: true,
                    hint: 'target +$targetUsd (${plan.weeklyTargetPct.round()}%)',
                    reached: targetHit,
                  ),
                  const SizedBox(height: 14),
                  _ProgressRow(
                    label: 'Weekly losses',
                    value: weekLoss,
                    max: lossLimitUsd,
                    money: true,
                    invert: true,
                    hint: 'stop trading if losses reach \$${lossLimitUsd.toStringAsFixed(2)} '
                        '(${plan.weeklyLossLimitPct.round()}%)',
                    exceeded: lossReached,
                  ),
                  const SizedBox(height: 14),
                  _ProgressRow(
                    label: 'Accuracy',
                    value: weekAccuracy,
                    max: plan.accuracyGoalPct,
                    percent: true,
                    hint: 'goal ${plan.accuracyGoalPct.round()}% · rightness is not a win guarantee',
                    reached: weekAccuracy >= plan.accuracyGoalPct,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1B232F),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.warn, size: 18),
                    SizedBox(width: 8),
                    Text('Risk per trade', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Only put \$${riskUsd.toStringAsFixed(2)} (${plan.riskPerTradePct.round()}% of balance) into any '
                  'single trade. If a trade would need more than that, skip it. '
                  'Never trade more than the plan allows, even if a signal looks great.',
                  style: const TextStyle(fontSize: 13.5, color: Color(0xFFC3CAD6), height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  GoalPlan _planFor(BuildContext context, String mindset, int week) {
    final all = GoalPlan.presets;
    return all.firstWhere(
      (p) => p.mindset == mindset && p.week == week,
      orElse: () => all.first,
    );
  }

  double _weekAccuracy(List<PaperTrade> closed) {
    final week = closed
        .where((t) => t.closedAt != null && _isThisWeek(t.closedAt!))
        .toList();
    if (week.isEmpty) return 0;
    final wins = week.where((t) => (t.pnl ?? 0) > 0).length;
    return wins / week.length * 100;
  }

  static bool _isToday(DateTime t) {
    final now = DateTime.now();
    return t.year == now.year && t.month == now.month && t.day == now.day;
  }

  static bool _isThisWeek(DateTime t) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    return !t.isBefore(start);
  }
}

class _PhaseCard extends StatelessWidget {
  final AppState appState;
  const _PhaseCard({required this.appState});

  @override
  Widget build(BuildContext context) {
    final real = appState.realPhase;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              real ? 'REAL MONEY PHASE' : 'PAPER LEARNING PHASE',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
                color: real ? AppTheme.warn : AppTheme.accent,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              real
                  ? 'You are trading real money. Follow the plan strictly and stop at the loss limit.'
                  : 'Fake money until your accuracy proves out. Flip to real when you are ready — '
                      'the goals count the same.',
              style: const TextStyle(fontSize: 13.5, color: Color(0xFFC3CAD6), height: 1.5),
            ),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Paper')),
                ButtonSegment(value: true, label: Text('Real money')),
              ],
              selected: {real},
              onSelectionChanged: (s) {
                if (s.first) {
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Switch to real money?'),
                      content: const Text(
                        'Only do this when your paper record looks good. Real losses are real.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Not yet'),
                        ),
                        FilledButton(
                          onPressed: () {
                            appState.setPhase(true);
                            Navigator.of(ctx).pop();
                          },
                          child: const Text('Switch'),
                        ),
                      ],
                    ),
                  );
                } else {
                  appState.setPhase(false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final String hint;
  final bool money;
  final bool percent;
  final bool reached;
  final bool exceeded;
  final bool invert;

  const _ProgressRow({
    required this.label,
    required this.value,
    required this.max,
    required this.hint,
    this.money = false,
    this.percent = false,
    this.reached = false,
    this.exceeded = false,
    this.invert = false,
  });

  @override
  Widget build(BuildContext context) {
    final progress = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    final Color color;
    if (exceeded) {
      color = AppTheme.sell;
    } else if (invert) {
      color = progress >= 0.6 ? AppTheme.warn : AppTheme.sell;
    } else if (reached) {
      color = AppTheme.buy;
    } else {
      color = AppTheme.accent;
    }

    final valueText = money
        ? '\$${value.toStringAsFixed(2)}'
        : percent
            ? '${value.toStringAsFixed(0)}%'
            : '${value.toInt()}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(
              valueText,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: exceeded || reached ? color : const Color(0xFFE6E9EF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            backgroundColor: const Color(0xFF232C3A),
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(hint, style: const TextStyle(fontSize: 12, color: Colors.white54)),
      ],
    );
  }
}
