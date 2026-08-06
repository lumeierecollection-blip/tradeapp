import 'package:flutter/material.dart';

import '../theme.dart';

class ProbabilityGauge extends StatelessWidget {
  final double value;
  final double size;

  const ProbabilityGauge({super.key, required this.value, this.size = 72});

  @override
  Widget build(BuildContext context) {
    final color = value >= 70
        ? AppTheme.buy
        : value >= 55
            ? AppTheme.warn
            : AppTheme.sell;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: value / 100,
            strokeWidth: 7,
            strokeCap: StrokeCap.round,
            color: color,
            backgroundColor: const Color(0xFF232C3A),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${value.round()}',
                  style: TextStyle(
                    fontSize: size * 0.32,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1,
                  ),
                ),
                Text(
                  '%',
                  style: TextStyle(
                    fontSize: size * 0.16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white54,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool center;
  final bool end;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.center = false,
    this.end = false,
  });

  @override
  Widget build(BuildContext context) {
    final alignment = center
        ? CrossAxisAlignment.center
        : end
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, letterSpacing: 0.3),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: valueColor ?? AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
