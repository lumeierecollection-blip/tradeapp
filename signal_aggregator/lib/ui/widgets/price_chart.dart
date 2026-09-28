import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../services/price_history_service.dart';
import '../theme.dart';

/// Line colour for a BUY / SELL / HOLD signal.
Color signalLineColor(String signal) {
  switch (signal.toUpperCase()) {
    case 'BUY':
      return AppTheme.buy;
    case 'SELL':
      return AppTheme.sell;
    default:
      return AppTheme.textSecondary;
  }
}

/// Close-price line chart. [compact] strips axes/grid for a card sparkline;
/// [markPrice] draws a dashed horizontal line (e.g. the signal's entry price).
class PriceChart extends StatelessWidget {
  final List<double> closes;
  final Color color;
  final bool compact;
  final double? markPrice;

  const PriceChart({
    super.key,
    required this.closes,
    required this.color,
    this.compact = true,
    this.markPrice,
  });

  @override
  Widget build(BuildContext context) {
    final spots = [for (var i = 0; i < closes.length; i++) FlSpot(i.toDouble(), closes[i])];
    var minY = closes.reduce((a, b) => a < b ? a : b);
    var maxY = closes.reduce((a, b) => a > b ? a : b);
    final mark = markPrice;
    if (mark != null) {
      if (mark < minY) minY = mark;
      if (mark > maxY) maxY = mark;
    }
    final pad = (maxY - minY) * 0.08;

    return LineChart(
      LineChartData(
        minY: minY - pad,
        maxY: maxY + pad,
        lineTouchData: LineTouchData(enabled: !compact),
        gridData: FlGridData(
          show: !compact,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => const FlLine(color: AppTheme.line, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          show: !compact,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: !compact,
              reservedSize: 56,
              getTitlesWidget: (value, meta) => Text(
                meta.formattedValue,
                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
              ),
            ),
          ),
        ),
        extraLinesData: ExtraLinesData(horizontalLines: [
          if (mark != null)
            HorizontalLine(
              y: mark,
              color: AppTheme.warn,
              strokeWidth: 1,
              dashArray: [4, 4],
              label: HorizontalLineLabel(
                show: !compact,
                alignment: Alignment.topLeft,
                style: const TextStyle(fontSize: 10, color: AppTheme.warn),
                labelResolver: (_) => 'signal price',
              ),
            ),
        ]),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            color: color,
            barWidth: compact ? 1.5 : 2,
            isCurved: false,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.1)),
          ),
        ],
      ),
    );
  }
}

/// Fetches [days] of daily closes for [symbol] and draws them; a flat grey
/// placeholder line while loading or when the fetch fails — never an error.
class PriceHistoryChart extends StatelessWidget {
  final String symbol;
  final Color color;
  final int days;
  final bool compact;
  final double? markPrice;
  final PriceHistoryService? service;

  const PriceHistoryChart({
    super.key,
    required this.symbol,
    required this.color,
    this.days = 30,
    this.compact = true,
    this.markPrice,
    this.service,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<double>>(
      future: (service ?? PriceHistoryService.shared).getPriceHistory(symbol, days: days),
      builder: (context, snap) {
        final closes = snap.data ?? const [];
        if (closes.length < 2) {
          return Center(
            key: const ValueKey('price-chart-placeholder'),
            child: Container(height: 1, color: AppTheme.line),
          );
        }
        return PriceChart(
          key: const ValueKey('price-chart'),
          closes: closes,
          color: color,
          compact: compact,
          markPrice: markPrice,
        );
      },
    );
  }
}
