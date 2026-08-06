import 'package:flutter/material.dart';

import '../../models/validated_signal.dart';
import '../theme.dart';

/// The exact buy and sell moments for a signal, shown as big clock times.
class BuySellTimes extends StatelessWidget {
  final ValidatedSignal vs;
  final bool large;

  const BuySellTimes({super.key, required this.vs, this.large = false});

  @override
  Widget build(BuildContext context) {
    final isBuy = vs.direction == Direction.buy;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _Block(
            label: 'BUY AT',
            time: AppTheme.fmtClock(vs.buyAt),
            detail: '\$${AppTheme.fmtPrice(vs.entry)}',
            large: large,
          ),
        ),
        Container(width: 1, height: large ? 64 : 44, color: AppTheme.line, margin: const EdgeInsets.symmetric(horizontal: 18)),
        Expanded(
          child: _Block(
            label: 'SELL AT',
            time: AppTheme.fmtClock(vs.sellAt),
            detail: '\$${AppTheme.fmtPrice(vs.takeProfit)} · ${isBuy ? '+' : '−'}${vs.upsidePct.toStringAsFixed(1)}%',
            large: large,
            color: isBuy ? AppTheme.buy : AppTheme.sell,
          ),
        ),
      ],
    );
  }
}

class _Block extends StatelessWidget {
  final String label;
  final String time;
  final String detail;
  final bool large;
  final Color? color;

  const _Block({
    required this.label,
    required this.time,
    required this.detail,
    required this.large,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.6,
            color: AppTheme.textMuted,
          ),
        ),
        SizedBox(height: large ? 10 : 6),
        Text(
          time,
          style: AppTheme.clockStyle(size: large ? 46 : 24, color: color ?? AppTheme.textPrimary),
        ),
        SizedBox(height: large ? 8 : 4),
        Text(
          detail,
          style: TextStyle(
            fontSize: large ? 13.5 : 12,
            fontWeight: FontWeight.w500,
            color: color ?? AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
