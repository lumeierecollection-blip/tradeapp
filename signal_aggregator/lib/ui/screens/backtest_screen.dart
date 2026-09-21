import 'package:flutter/material.dart';

import '../../services/github_data_service.dart';
import '../theme.dart';

class BacktestScreen extends StatefulWidget {
  const BacktestScreen({super.key});

  @override
  State<BacktestScreen> createState() => _BacktestScreenState();
}

class _BacktestScreenState extends State<BacktestScreen> {
  final _data = GithubDataService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _matrixRows = [];
  String _sortBy = 'sharpe';
  bool _sortAsc = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final matrix = await _data.getBacktestMatrix();
      final rows = (matrix['results'] as List<dynamic>? ?? [])
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      if (!mounted) return;
      setState(() { _matrixRows = rows; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = '$e'; _loading = false; });
    }
  }

  void _sort(String field) {
    setState(() {
      if (_sortBy == field) {
        _sortAsc = !_sortAsc;
      } else {
        _sortBy = field;
        _sortAsc = field == 'symbol' || field == 'strategy';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sorted = List<Map<String, dynamic>>.from(_matrixRows)
      ..sort((a, b) {
        final av = a[_sortBy] ?? 0;
        final bv = b[_sortBy] ?? 0;
        int cmp;
        if (av is String && bv is String) {
          cmp = av.compareTo(bv);
        } else {
          cmp = (av is num ? av : 0).compareTo(bv is num ? bv : 0);
        }
        return _sortAsc ? cmp : -cmp;
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Strategy Matrix'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 40, color: AppTheme.sell),
                        const SizedBox(height: 12),
                        Text(_error!, style: const TextStyle(color: AppTheme.textSecondary)),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _matrixRows.isEmpty
                  ? const Center(
                      child: Text('No backtest results yet.',
                          style: TextStyle(color: AppTheme.textMuted)),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          _summaryCard(),
                          const SizedBox(height: 12),
                          _tableCard(sorted),
                        ],
                      ),
                    ),
    );
  }

  Widget _summaryCard() {
    if (_matrixRows.isEmpty) return const SizedBox.shrink();
    final sharpes = _matrixRows.map((r) => (r['sharpe'] ?? 0).toDouble()).toList();
    final avg = sharpes.reduce((a, b) => a + b) / sharpes.length;
    final best = sharpes.reduce((a, b) => a > b ? a : b);
    final worst = sharpes.reduce((a, b) => a < b ? a : b);
    final profitable = sharpes.where((s) => s > 0).length;
    final bestRow = _matrixRows.firstWhere(
      (r) => (r['sharpe'] ?? 0).toDouble() == best,
      orElse: () => {},
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(
              children: [
                _stat('Avg Sharpe', avg.toStringAsFixed(2), avg > 0 ? AppTheme.buy : AppTheme.sell),
                const SizedBox(width: 16),
                _stat('Best', best.toStringAsFixed(2), AppTheme.buy),
                const SizedBox(width: 16),
                _stat('Worst', worst.toStringAsFixed(2), AppTheme.sell),
                const SizedBox(width: 16),
                _stat('Profitable', '$profitable/${_matrixRows.length}', AppTheme.textPrimary),
              ],
            ),
            if (bestRow.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Best combo: ${bestRow['symbol']} · ${bestRow['strategy']} · ${bestRow['timeframe']}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _tableCard(List<Map<String, dynamic>> rows) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        child: DataTable(
          headingTextStyle: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 0.5),
          dataTextStyle: const TextStyle(fontSize: 12.5, color: AppTheme.textPrimary),
          columnSpacing: 16,
          columns: [
            _col('Symbol', 'symbol'),
            _col('Strategy', 'strategy'),
            _col('TF', 'timeframe'),
            _col('Sharpe', 'sharpe'),
            _col('Max DD', 'max_dd'),
            _col('Win%', 'win_rate'),
            _col('Return%', 'total_return'),
            _col('Trades', 'trades'),
          ],
          rows: rows.map((r) {
            final sharpe = (r['sharpe'] ?? 0).toDouble();
            final ret = (r['total_return'] ?? 0).toDouble();
            final maxDd = (r['max_dd'] ?? 0).toDouble();
            return DataRow(cells: [
              DataCell(Text(r['symbol'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text(r['strategy'] ?? '')),
              DataCell(Text(r['timeframe'] ?? '')),
              DataCell(Text(sharpe.toStringAsFixed(2),
                  style: TextStyle(color: sharpe > 0 ? AppTheme.buy : AppTheme.sell, fontWeight: FontWeight.w700))),
              DataCell(Text(maxDd.toStringAsFixed(1),
                  style: TextStyle(color: maxDd > 10 ? AppTheme.sell : AppTheme.textSecondary))),
              DataCell(Text('${(r['win_rate'] ?? 0).toDouble().toStringAsFixed(0)}%')),
              DataCell(Text(ret.toStringAsFixed(1),
                  style: TextStyle(color: ret > 0 ? AppTheme.buy : AppTheme.sell))),
              DataCell(Text('${r['trades'] ?? 0}')),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  DataColumn _col(String label, String field) {
    final isSorted = _sortBy == field;
    return DataColumn(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (isSorted)
            Icon(
              _sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
              size: 12,
              color: AppTheme.accent,
            ),
        ],
      ),
      onSort: (_, __) => _sort(field),
    );
  }
}
