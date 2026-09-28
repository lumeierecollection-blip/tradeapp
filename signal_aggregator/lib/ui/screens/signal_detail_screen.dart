import 'dart:convert';

import 'package:flutter/material.dart';

import '../../services/price_history_service.dart';
import '../theme.dart';
import '../widgets/price_chart.dart';

/// One model signal: header, 90-day close chart with the signal price marked,
/// and every field from the signal JSON. Display only.
class SignalDetailScreen extends StatelessWidget {
  final Map<String, dynamic> signal;
  final PriceHistoryService? priceHistory;

  const SignalDetailScreen({super.key, required this.signal, this.priceHistory});

  @override
  Widget build(BuildContext context) {
    final symbol = (signal['symbol'] ?? '').toString();
    final action = (signal['signal'] ?? 'HOLD').toString().toUpperCase();
    final confidence = signal['confidence'];
    final price = signal['price'];
    final color = signalLineColor(action);

    return Scaffold(
      appBar: AppBar(title: Text(symbol)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(symbol, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.6)),
                ),
                child: Text(action,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.5)),
              ),
              if (confidence is num) ...[
                const SizedBox(width: 10),
                Text('${(confidence * 100).round()}%',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 8),
                    child: Text('90-day daily close',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  ),
                  SizedBox(
                    height: 220,
                    child: PriceHistoryChart(
                      symbol: symbol,
                      color: color,
                      days: 90,
                      compact: false,
                      markPrice: price is num ? price.toDouble() : null,
                      service: priceHistory,
                    ),
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
                  _row('Price', price is num ? AppTheme.fmtQuote(symbol, price.toDouble()) : '—'),
                  _row('Regime', signal['regime']?.toString() ?? '—'),
                  _row('Generated', _fmtTime(signal['generated_at'])),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('All fields', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final e in signal.entries) _row(e.key, _fmtValue(e.value)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Informational only. Yahoo data is 15–20 min delayed. Not financial advice.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  static String _fmtTime(dynamic raw) {
    final t = DateTime.tryParse(raw?.toString() ?? '');
    return t == null ? '—' : '${AppTheme.fmtFullTime(t)} (local)';
  }

  static String _fmtValue(dynamic v) {
    if (v == null) return '—';
    if (v is Map || v is List) return const JsonEncoder.withIndent('  ').convert(v);
    return v.toString();
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary))),
        ],
      ),
    );
  }
}
