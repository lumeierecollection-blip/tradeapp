import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../journal/journal.dart';
import '../../journal/journal_entry.dart';
import '../../journal/mistake_tags.dart';
import '../theme.dart';

/// Closed-trade review: tag each finished paper trade by hand and see which
/// mistakes keep costing money.
class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final journal = context.watch<Journal>();
    final closed = journal.ofKind(JournalKind.tradeClosed).reversed.toList();
    final stats = journal.tagStats();

    return Scaffold(
      appBar: AppBar(title: const Text('Review')),
      body: closed.isEmpty
          ? const _Empty()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (stats.isNotEmpty) ...[
                  _TagSummary(stats: stats),
                  const SizedBox(height: 20),
                ],
                const Text('Closed trades',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textMuted)),
                const SizedBox(height: 8),
                for (final e in closed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ReviewCard(entry: e),
                  ),
              ],
            ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'No closed trades yet. Once a paper trade finishes it shows up here to tag.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textMuted, height: 1.5),
        ),
      ),
    );
  }
}

class _TagSummary extends StatelessWidget {
  final List<TagStat> stats;
  const _TagSummary({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            for (final s in stats)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(MistakeTag.labelFor(s.tag),
                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    ),
                    Text('${s.trades}x', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 54,
                      child: Text('${s.winRate.round()}% W',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 64,
                      child: Text(
                        '${s.totalPnl >= 0 ? '+' : ''}${s.totalPnl.toStringAsFixed(0)}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: s.totalPnl >= 0 ? AppTheme.buy : AppTheme.sell,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final JournalEntry entry;
  const _ReviewCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final journal = context.read<Journal>();
    final pnl = entry.pnl ?? 0.0;
    final tags = entry.tags.toSet();
    final tradeId = entry.tradeId;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('${entry.direction} ${entry.symbol}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                Text(entry.closedBy ?? '',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                const Spacer(),
                Text(
                  '${pnl >= 0 ? '+' : ''}${pnl.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: pnl >= 0 ? AppTheme.buy : AppTheme.sell,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(AppTheme.fmtFullTime(entry.at),
                style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in MistakeTag.values)
                  FilterChip(
                    label: Text(tag.label, style: const TextStyle(fontSize: 11.5)),
                    selected: tags.contains(tag.id),
                    onSelected: tradeId == null
                        ? null
                        : (selected) {
                            final next = {...tags};
                            if (selected) {
                              next.add(tag.id);
                            } else {
                              next.remove(tag.id);
                            }
                            journal.setTags(tradeId, next.toList());
                          },
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
