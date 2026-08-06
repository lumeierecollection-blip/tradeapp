import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/paper_trade.dart';
import '../../models/validated_signal.dart';
import '../../services/paper_trader.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/buy_sell_times.dart';
import '../widgets/probability_gauge.dart';

class SignalDetailScreen extends StatefulWidget {
  final ValidatedSignal vs;
  const SignalDetailScreen({super.key, required this.vs});

  @override
  State<SignalDetailScreen> createState() => _SignalDetailScreenState();
}

class _SignalDetailScreenState extends State<SignalDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final vs = widget.vs;
    final color = AppTheme.directionColor(vs.direction);
    final isBuy = vs.direction == Direction.buy;
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: Text('${vs.direction.label} ${vs.symbol}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          BuySellTimes(vs: vs, large: true),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: now.isBefore(vs.sellAt) ? color : AppTheme.textMuted,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${vs.status(now)} · ${AppTheme.fmtUntil(vs.sellAt)}',
                  style: const TextStyle(fontSize: 13.5, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Times are exact — set from how fast price is moving toward the target right now.',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  ProbabilityGauge(value: vs.probability, size: 74),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${vs.probability.round()}% chance\nthis works',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, height: 1.25),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Scored from momentum, volume, RSI, entry zone and message clarity.',
                          style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(child: StatTile(label: 'Entry', value: AppTheme.fmtPrice(vs.entry))),
                  Container(width: 1, height: 34, color: AppTheme.line),
                  Expanded(
                    child: StatTile(
                      label: 'Stop loss',
                      value: AppTheme.fmtPrice(vs.stopLoss),
                      valueColor: AppTheme.sell,
                      center: true,
                    ),
                  ),
                  Container(width: 1, height: 34, color: AppTheme.line),
                  Expanded(
                    child: StatTile(
                      label: 'Target',
                      value: AppTheme.fmtPrice(vs.takeProfit),
                      valueColor: isBuy ? AppTheme.buy : AppTheme.sell,
                      end: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _tag('Risk : reward ${vs.riskRewardText}'),
              const SizedBox(width: 8),
              _tag('Upside ${isBuy ? '+' : '−'}${vs.upsidePct.toStringAsFixed(1)}%'),
            ],
          ),
          const SizedBox(height: 28),
          const _SectionTitle('Why this signal'),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                vs.summary,
                style: const TextStyle(fontSize: 14.5, color: AppTheme.textSecondary, height: 1.6),
              ),
            ),
          ),
          const SizedBox(height: 28),
          const _SectionTitle('How it scores'),
          const SizedBox(height: 10),
          for (final factor in vs.factors) _FactorRow(factor: factor),
          const SizedBox(height: 28),
          const _SectionTitle('Where it came from'),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${vs.signal.sourceName} — ${vs.signal.author.isEmpty ? '' : '${vs.signal.author} · '}${AppTheme.timeAgo(vs.signal.postedAt)}',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  if (vs.signal.title.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(vs.signal.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    vs.signal.text.isEmpty ? vs.signal.title : vs.signal.text,
                    style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.55),
                  ),
                  if (vs.signal.url.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () => launchUrl(Uri.parse(vs.signal.url)),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Open original post'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          if (isBuy)
            FilledButton.icon(
              onPressed: () => _openPaperTrade(context, vs),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.buy,
                foregroundColor: const Color(0xFF06210F),
              ),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Paper trade this signal'),
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.sell.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.sell.withValues(alpha: 0.25)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.sell, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This is a SELL warning: the market looks weak, so avoid buying right now. Paper trades only open on BUY signals.',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _openPaperTrade(BuildContext context, ValidatedSignal vs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceAlt,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _PaperTradeSheet(vs: vs),
    );
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.line),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.2),
    );
  }
}

class _PaperTradeSheet extends StatefulWidget {
  final ValidatedSignal vs;
  const _PaperTradeSheet({required this.vs});

  @override
  State<_PaperTradeSheet> createState() => _PaperTradeSheetState();
}

class _PaperTradeSheetState extends State<_PaperTradeSheet> {
  PositionType _type = PositionType.accumulate;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _defaultFor(_type).toStringAsFixed(2));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _defaultFor(PositionType type) {
    final balance = context.read<AppState>().paperTrader.balance;
    final pct = type == PositionType.conviction ? 0.30 : 0.10;
    return balance * pct;
  }

  void _onTypeChanged(PositionType type) {
    setState(() {
      _type = type;
      _controller.text = _defaultFor(type).toStringAsFixed(2);
    });
  }

  @override
  Widget build(BuildContext context) {
    final vs = widget.vs;
    final appState = context.read<AppState>();
    final trader = appState.paperTrader;
    final risk = (vs.entry - vs.stopLoss).abs();
    final target = _type == PositionType.conviction ? vs.takeProfit : vs.entry + risk * PaperTrader.accumulateRewardMultiple;
    final upside = target > 0 ? ((target - vs.entry) / vs.entry) * 100 : 0.0;

    return Padding(
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 22,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Paper trade BUY ${vs.symbol}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            'Entry \$${AppTheme.fmtPrice(vs.entry)} · Stop \$${AppTheme.fmtPrice(vs.stopLoss)} · close ${AppTheme.fmtClock(vs.sellAt)}',
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<PositionType>(
              segments: [
                for (final type in PositionType.values)
                  ButtonSegment(value: type, label: Text(type.label)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => _onTypeChanged(s.first),
              showSelectedIcon: false,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_type.hint,
                    style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.4)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _sheetStat('Target', '\$${AppTheme.fmtPrice(target)}'),
                    const SizedBox(width: 18),
                    _sheetStat('Upside', '+${upside.toStringAsFixed(1)}%'),
                    const SizedBox(width: 18),
                    _sheetStat('Risk', '\$${AppTheme.fmtPrice(vs.stopLoss)}'),
                  ],
                ),
                if (_type == PositionType.conviction) ...[
                  const SizedBox(height: 10),
                  Text(
                    '${PaperTrader.convictionPerDay - trader.convictionUsedToday} of ${PaperTrader.convictionPerDay} conviction slots left today.',
                    style: const TextStyle(fontSize: 12, color: AppTheme.warn),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount (paper USD)',
              prefixText: '\$ ',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Available paper balance: \$${trader.balance.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.notifications_active_outlined, size: 15, color: AppTheme.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Reminders at 5 min and 2 min before, and exactly at ${AppTheme.fmtClock(vs.sellAt)}, to close this position.',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                final appState = context.read<AppState>();
                final amount = double.tryParse(_controller.text.replaceAll(',', '.'));
                if (amount == null) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Enter a valid number')),
                  );
                  return;
                }
                final result = await appState.openTrade(widget.vs, amount, type: _type);
                if (!mounted) return;
                if (result.isNotEmpty) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(result)),
                  );
                  return;
                }
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      'Opened ${_type.label.toLowerCase()} ${widget.vs.symbol} trade for \$${amount.toStringAsFixed(2)} · reminders set for ${AppTheme.fmtClock(widget.vs.sellAt)}',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.check),
              label: const Text('Confirm'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, letterSpacing: 0.6)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
      ],
    );
  }
}

class _FactorRow extends StatelessWidget {
  final FactorScore factor;
  const _FactorRow({required this.factor});

  @override
  Widget build(BuildContext context) {
    final color = factor.score >= 70
        ? AppTheme.buy
        : factor.score >= 45
            ? AppTheme.warn
            : AppTheme.sell;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(factor.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
                Text('${factor.score.round()}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: factor.score / 100,
                minHeight: 5,
                backgroundColor: AppTheme.line,
                color: color,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              factor.plain,
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
