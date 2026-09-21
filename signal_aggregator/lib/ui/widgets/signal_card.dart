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
        borderRadius: BorderRadius.circular(10),
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
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceAlt,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.line),
                    ),
                    child: Text(
                      vs.setupTier.toUpperCase().replaceAll('_', ' '),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
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
                  _freshnessBadge(vs.signal.postedAt),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right, size: 18, color: AppTheme.textMuted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shows a colored dot indicating signal freshness:
  /// green < 1h, yellow < 6h, red > 6h.
  Widget _freshnessBadge(DateTime postedAt) {
    final age = DateTime.now().difference(postedAt);
    final Color dotColor;
    String label;
    if (age.inMinutes < 60) {
      dotColor = AppTheme.buy;
      label = 'fresh';
    } else if (age.inHours < 6) {
      dotColor = AppTheme.warn;
      label = '${age.inHours}h old';
    } else {
      dotColor = AppTheme.sell;
      label = '${age.inHours}h old';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: dotColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: dotColor)),
        ],
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
