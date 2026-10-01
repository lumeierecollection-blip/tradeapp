import 'package:flutter/material.dart';

import '../../services/github_data_service.dart';
import '../../services/historical_price_service.dart';
import '../../services/signal_performance.dart';
import '../theme.dart';

/// Live track record: every logged BUY/SELL (signal_history.json) scored against
/// the price a day / a week later. Unlike the backtests, nothing here is fitted.
class SignalPerformanceScreen extends StatefulWidget {
  final GithubDataService? data;
  final HistoricalPriceService? prices;

  const SignalPerformanceScreen({super.key, this.data, this.prices});

  @override
  State<SignalPerformanceScreen> createState() => _SignalPerformanceScreenState();
}

class _SignalPerformanceScreenState extends State<SignalPerformanceScreen> {
  static const _horizons = {'1 day': Duration(days: 1), '1 week': Duration(days: 7)};
  static const _minSample = 30;
  static const _maxRows = 200;

  late final GithubDataService _data = widget.data ?? GithubDataService();
  late final HistoricalPriceService _prices = widget.prices ?? HistoricalPriceService.shared;

  bool _loading = true;
  bool _error = false;
  List<LoggedSignal> _signals = [];
  Map<String, List<PriceBar>> _bars = {};
  String _horizon = '1 day';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    setState(() { _loading = true; _error = false; });
    final history = await _data.getSignalHistory(force: force);
    final signals = SignalPerformance.parseHistory(history);
    final symbols = signals.map((s) => s.symbol).toSet().toList();
    final fetched = await Future.wait(symbols.map(_prices.getDailyBars));
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = history.isEmpty;
      _signals = signals;
      _bars = {for (var i = 0; i < symbols.length; i++) symbols[i]: fetched[i]};
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Signal Performance'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : () => _load(force: true)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: () => _load(force: true), child: _body()),
    );
  }

  Widget _body() {
    if (_error) {
      return _message(Icons.cloud_off, 'No signal history yet.\nIt is logged after each ML run (every 6 hours).');
    }
    if (_signals.isEmpty) {
      return _message(Icons.hourglass_empty, 'History exists, but it has no BUY/SELL signals to score yet.');
    }
    final summary = SignalPerformance.evaluate(_signals, _bars, _horizons[_horizon]!);
    final rows = summary.results.reversed.take(_maxRows).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final h in _horizons.keys)
              ChoiceChip(label: Text(h), selected: _horizon == h, onSelected: (_) => setState(() => _horizon = h)),
          ],
        ),
        const SizedBox(height: 12),
        _metrics(summary),
        const SizedBox(height: 8),
        if (summary.scoredCount < _minSample)
          _note('Only ${summary.scoredCount} scored signals — far too few to judge the model. '
              'Treat these numbers as noise until there are at least $_minSample.'),
        _note('HOLD signals are excluded. P&L is the raw price move from the logged price to the first completed '
            'daily close after the $_horizon mark, in the signal\'s direction — before spreads, fees and slippage.'),
        const SizedBox(height: 8),
        const Text('SIGNALS', style: TextStyle(fontSize: 11, letterSpacing: 1, color: AppTheme.textMuted)),
        const SizedBox(height: 6),
        for (final r in rows) _row(r),
        if (summary.results.length > rows.length)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('Showing latest ${rows.length} of ${summary.results.length}.',
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ),
      ],
    );
  }

  Widget _metrics(PerformanceSummary s) {
    final wr = s.winRate;
    return Column(
      children: [
        Row(children: [
          _tile('Win rate', wr == null ? '—' : '${wr.toStringAsFixed(1)}%',
              wr == null ? AppTheme.textPrimary : (wr >= 50 ? AppTheme.buy : AppTheme.sell)),
          const SizedBox(width: 8),
          _tile('Avg win', _pct(s.avgWin), AppTheme.buy),
          const SizedBox(width: 8),
          _tile('Avg loss', _pct(s.avgLoss), AppTheme.sell),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _tile('Scored', '${s.scoredCount}', AppTheme.textPrimary),
          const SizedBox(width: 8),
          _tile('Pending', '${s.pending}', AppTheme.textSecondary),
          const SizedBox(width: 8),
          _tile('Avg P&L', _pct(s.avgPnl), _pnlColor(s.avgPnl)),
        ]),
      ],
    );
  }

  Widget _tile(String label, String value, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(SignalResult r) {
    final s = r.signal;
    final dirColor = s.direction == 'BUY' ? AppTheme.buy : AppTheme.sell;
    final (label, color) = switch (r.outcome) {
      Outcome.win => ('WIN', AppTheme.buy),
      Outcome.loss => ('LOSS', AppTheme.sell),
      Outcome.pending => ('PENDING', AppTheme.textMuted),
    };
    final d = s.generatedAt;
    final date = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(s.symbol,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 8),
                    Text(s.direction, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: dirColor)),
                  ]),
                  const SizedBox(height: 2),
                  Text(
                    '$date · ${AppTheme.fmtQuote(s.symbol, s.entryPrice)}'
                    '${r.exitPrice == null ? '' : ' → ${AppTheme.fmtQuote(s.symbol, r.exitPrice!)}'}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                const SizedBox(height: 2),
                Text(_pct(r.pnlPct),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _pnlColor(r.pnlPct))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _note(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
      );

  Widget _message(IconData icon, String text) {
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 40, color: AppTheme.textMuted),
                const SizedBox(height: 12),
                Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 16),
                FilledButton(onPressed: () => _load(force: true), child: const Text('Retry')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _pct(double? v) => v == null ? '—' : '${v >= 0 ? '+' : ''}${v.toStringAsFixed(2)}%';

  static Color _pnlColor(double? v) =>
      v == null || v == 0 ? AppTheme.textSecondary : (v > 0 ? AppTheme.buy : AppTheme.sell);
}
