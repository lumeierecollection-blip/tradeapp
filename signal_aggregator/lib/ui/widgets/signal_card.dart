import 'package:flutter/material.dart';

import '../../models/validated_signal.dart';
import '../theme.dart';
import 'buy_sell_times.dart';

class SignalCard extends StatelessWidget {
  final ValidatedSignal vs;
  final VoidCallback onTap;

  const SignalCard({super.key, required this.vs, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.directionColor(vs.direction);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    vs.direction.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    vs.symbol,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                  ),
                  const Spacer(),
                  Text(
                    '${vs.probability.round()}%',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'rightness',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              BuySellTimes(vs: vs),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.public, size: 12, color: AppTheme.textMuted),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      '${vs.signal.sourceName} · ${AppTheme.timeAgo(vs.signal.postedAt)}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right, size: 18, color: AppTheme.textMuted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}
