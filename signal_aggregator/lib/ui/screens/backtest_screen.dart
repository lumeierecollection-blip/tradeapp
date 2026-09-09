import 'dart:math';

import 'package:flutter/material.dart';

import '../../backtesting/backtest_engine.dart';
import '../../backtesting/binance_history.dart';
import '../../backtesting/performance_metrics.dart';
import '../../backtesting/strategy.dart';
import '../theme.dart';

/// Runs the RSI-dip strategy over recent Binance candles and shows the result.
/// Costs (spread, slippage, taker fee) are applied to every fill by the engine.
class BacktestScreen extends StatefulWidget {
  const BacktestScreen({super.key});

  @override
  State<BacktestScreen> createState() => _BacktestScreenState();
}

class _BacktestScreenState extends State<BacktestScreen> {
  static const _symbols = [
    'BTC', 'ETH', 'SOL', 'BNB', 'XRP', 'ADA', 'DOGE', 'AVAX', 'LINK'
  ];
  static const _intervals = ['1h', '4h', '1d'];

  String _symbol = 'BTC';
  String _interval = '1h';
  double _stopPct = 5;
  double _targetPct = 10;
  double _riskPct = 2;

  bool _running = false;
  String? _error;
  BacktestResult? _result;
  PerformanceMetrics? _metrics;

  Future<void> _run() async {
    setState(() {
      _running = true;
      _error = null;
    });
    final api = BinanceHistory();
    try {
      final bars = await api.fetch(symbol: _symbol, interval: _interval, limit: 500);
      if (bars.length < 30) {
        throw Exception('Only ${bars.length} candles came back — need at least 30.');
      }
      final result = runBacktest(
        bars: bars,
        strategy: const RsiDipStrategy(),
        config: BacktestConfig(
          initialBalance: 500,
          stopLossPct: _stopPct / 100,
          takeProfitPct: _targetPct / 100,
          riskPerTradePct: _riskPct / 100,
        ),
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _metrics = PerformanceMetrics.of(result);
        _running = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _running = false;
      });
    } finally {
      api.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backtest')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _configCard(),
          const SizedBox(height: 16),
          if (_running)
            const Center(
              child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()),
            ),
          if (_error != null && !_running)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.sell.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.sell.withValues(alpha: 0.4)),
              ),
              child: Text(_error!, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            ),
          if (_result != null && !_running) ...[
            _EquityChart(points: _result!.equityCurve, initial: _result!.config.initialBalance),
            const SizedBox(height: 16),
            _MetricsTable(rows: _metrics!.table()),
            const SizedBox(height: 16),
            _TradesList(trades: _result!.trades),
          ],
          if (_result == null && !_running && _error == null)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Text(
                'Runs the RSI-dip strategy over the last 500 candles from Binance. '
                'Entries fill on the next bar open; spread, slippage and taker fees '
                'are charged on every fill.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, height: 1.5),
              ),
            ),
        ],
      ),
    );
  }

  Widget _configCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _symbol,
                    decoration: const InputDecoration(labelText: 'Coin', isDense: true),
                    items: [
                      for (final s in _symbols) DropdownMenuItem(value: s, child: Text(s)),
                    ],
                    onChanged: _running ? null : (v) => setState(() => _symbol = v ?? _symbol),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SegmentedButton<String>(
                    segments: [
                      for (final i in _intervals) ButtonSegment(value: i, label: Text(i)),
                    ],
                    selected: {_interval},
                    onSelectionChanged:
                        _running ? null : (s) => setState(() => _interval = s.first),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _slider('Stop loss', _stopPct, 1, 20, (v) => setState(() => _stopPct = v)),
            _slider('Take profit', _targetPct, 2, 40, (v) => setState(() => _targetPct = v)),
            _slider('Risk per trade', _riskPct, 1, 10, (v) => setState(() => _riskPct = v)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _running ? null : _run,
                child: Text(_running ? 'Running…' : 'Run backtest'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).round(),
            label: '${value.round()}%',
            onChanged: _running ? null : onChanged,
          ),
        ),
        SizedBox(
          width: 42,
          child: Text('${value.round()}%',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _EquityChart extends StatelessWidget {
  final List<EquityPoint> points;
  final double initial;
  const _EquityChart({required this.points, required this.initial});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 170,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.line),
      ),
      child: points.length < 2
          ? const Center(
              child: Text('Not enough data for a curve',
                  style: TextStyle(color: AppTheme.textMuted)))
          : CustomPaint(painter: _EquityPainter(points, initial), size: Size.infinite),
    );
  }
}

class _EquityPainter extends CustomPainter {
  final List<EquityPoint> points;
  final double initial;
  _EquityPainter(this.points, this.initial);

  @override
  void paint(Canvas canvas, Size size) {
    final values = points.map((p) => p.equity).toList();
    var lo = initial;
    var hi = initial;
    for (final v in values) {
      lo = min(lo, v);
      hi = max(hi, v);
    }
    if (hi - lo < 1e-9) hi = lo + 1;

    double px(int i) => size.width * i / (points.length - 1);
    double py(double v) => size.height * (1 - (v - lo) / (hi - lo));

    final base = Paint()
      ..color = AppTheme.textMuted.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, py(initial)), Offset(size.width, py(initial)), base);

    final path = Path()..moveTo(px(0), py(values.first));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(px(i), py(values[i]));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = values.last >= initial ? AppTheme.buy : AppTheme.sell
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _EquityPainter old) =>
      old.points != points || old.initial != initial;
}

class _MetricsTable extends StatelessWidget {
  final Map<String, String> rows;
  const _MetricsTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    final entries = rows.entries.toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(e.key,
                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    ),
                    Text(e.value,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TradesList extends StatelessWidget {
  final List<BacktestTrade> trades;
  const _TradesList({required this.trades});

  @override
  Widget build(BuildContext context) {
    if (trades.isEmpty) {
      return const Text('No trades were taken over this window.',
          style: TextStyle(color: AppTheme.textMuted));
    }
    final shown = trades.length > 40 ? trades.sublist(trades.length - 40) : trades;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            for (final t in shown)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${AppTheme.fmtClock(t.entryTime)} → ${AppTheme.fmtClock(t.exitTime)} · ${t.reason.label}',
                        style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                      ),
                    ),
                    Text(
                      '${t.netPnl >= 0 ? '+' : ''}${t.netPnl.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: t.netPnl >= 0 ? AppTheme.buy : AppTheme.sell,
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
