import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/validated_signal.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/signal_card.dart';

class SignalsScreen extends StatefulWidget {
  const SignalsScreen({super.key});

  @override
  State<SignalsScreen> createState() => _SignalsScreenState();
}

class _SignalsScreenState extends State<SignalsScreen> {
  Direction? _filter;
  String? _symbol;
  final Set<String> _expanded = {};

  void _toggle(String id) => setState(() {
        if (!_expanded.remove(id)) _expanded.add(id);
      });

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final all = appState.validated;
    var filtered = _filter == null ? all : all.where((v) => v.direction == _filter).toList();
    if (_symbol != null) {
      filtered = filtered.where((v) => v.symbol == _symbol).toList();
    }
    final symbols = all.map((v) => v.symbol).toSet().toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Signals'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: appState.isLoading ? null : appState.refresh,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<Direction?>(
                segments: const [
                  ButtonSegment(value: null, label: Text('All'), icon: Icon(Icons.all_inclusive, size: 18)),
                  ButtonSegment(value: Direction.buy, label: Text('Buy'), icon: Icon(Icons.trending_up, size: 18)),
                  ButtonSegment(value: Direction.sell, label: Text('Sell'), icon: Icon(Icons.trending_down, size: 18)),
                ],
                selected: {_filter},
                onSelectionChanged: (s) => setState(() => _filter = s.first),
              ),
            ),
          ),
          if (symbols.length > 1)
            SizedBox(
              height: 40,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: symbols.length + 1,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final symbol = i == 0 ? null : symbols[i - 1];
                  final selected = _symbol == symbol;
                  return ChoiceChip(
                    label: Text(symbol ?? 'All'),
                    selected: selected,
                    onSelected: (_) => setState(() => _symbol = symbol),
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: selected ? AppTheme.bg : AppTheme.textSecondary,
                    ),
                    selectedColor: AppTheme.accent,
                    backgroundColor: AppTheme.surfaceAlt,
                    side: const BorderSide(color: AppTheme.line),
                  );
                },
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: appState.refresh,
              child: filtered.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 120),
                        EmptyState(
                          icon: Icons.search_off,
                          title: 'No signals found',
                          message: 'No ${_filter?.label.toLowerCase() ?? ''} signals right now. '
                              'Signals appear when a post talks about a coin AND the market agrees.',
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final vs = filtered[i];
                        final open = _expanded.contains(vs.signal.id);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            children: [
                              SignalCard(
                                vs: vs,
                                onTap: () => _toggle(vs.signal.id),
                              ),
                              if (open) _SignalDetail(vs: vs),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline "why this signal" panel shown under a tapped [SignalCard].
class _SignalDetail extends StatelessWidget {
  final ValidatedSignal vs;
  const _SignalDetail({required this.vs});

  @override
  Widget build(BuildContext context) {
    final reasons = vs.reasons.isNotEmpty ? vs.reasons : vs.factors;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            vs.summary,
            style: const TextStyle(fontSize: 13.5, color: AppTheme.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _Stat(label: 'ENTRY', value: '\$${AppTheme.fmtPrice(vs.entry)}'),
              _Stat(label: 'STOP', value: '\$${AppTheme.fmtPrice(vs.stopLoss)}', color: AppTheme.sell),
              _Stat(label: 'TARGET', value: '\$${AppTheme.fmtPrice(vs.takeProfit)}', color: AppTheme.buy),
              _Stat(label: 'RISK : REWARD', value: vs.riskRewardText),
            ],
          ),
          if (vs.entryWindow.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Entry window: ${vs.entryWindow}',
                style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted)),
          ],
          if (reasons.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 10),
            for (final f in reasons)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.label,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    if (f.plain.isNotEmpty)
                      Text(f.plain,
                          style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.45)),
                  ],
                ),
              ),
          ],
          if (vs.targetReason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Target: ${vs.targetReason}',
                style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted, height: 1.45)),
          ],
          if (vs.stopReason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Stop: ${vs.stopReason}',
                style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted, height: 1.45)),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Stat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1, color: AppTheme.textMuted)),
        const SizedBox(height: 3),
        Text(value,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800, color: color ?? AppTheme.textPrimary)),
      ],
    );
  }
}
