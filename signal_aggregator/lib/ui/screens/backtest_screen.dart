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
      final matrix = await _data.getWalkForwardMatrix();
      final rows = (matrix['rows'] as List<dynamic>? ?? [])
          .map((r) => Map<String, dynamic>.from(r as Map))
          .where((r) => !r.containsKey('error'))
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
        title: const Text('Walk-Forward Matrix'),
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
                      child: Text('No walk-forward results yet.\nRun the matrix generator first.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textMuted)),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          _warningBanner(),
                          _summaryCard(),
                          const SizedBox(height: 12),
                          _tableCard(sorted),
                        ],
                      ),
                    ),
    );
  }

  int get _survivorCount => _matrixRows.where((r) {
    final sharpe = (r['avg_oos_sharpe'] ?? 0).toDouble();
    final pos = (r['pct_positive'] ?? 0).toDouble();
    final windows = (r['windows'] ?? 0) as int;
    return sharpe > 0.5 && pos >= 50 && windows >= 3;
  }).length;

  Widget _warningBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.warn.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.warn.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.warn, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'In-sample results are misleading. Only combinations with avg_sharpe > 0.5 AND '
              '% positive >= 50% AND windows >= 3 are candidates. '
              'Currently: ${_survivorCount} combos meet this bar.',
              style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    if (_matrixRows.isEmpty) return const SizedBox.shrink();
    final sharpes = _matrixRows.map((r) => (r['avg_oos_sharpe'] ?? 0).toDouble()).toList();
    final avg = sharpes.reduce((a, b) => a + b) / sharpes.length;
    final best = sharpes.reduce((a, b) => a > b ? a : b);
    final worst = sharpes.reduce((a, b) => a < b ? a : b);
    final profitable = sharpes.where((s) => s > 0).length;
    final bestRow = _matrixRows.firstWhere(
      (r) => (r['avg_oos_sharpe'] ?? 0).toDouble() == best,
      orElse: () => {},
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Walk-Forward Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
                'Best combo: ${bestRow['symbol']} · ${bestRow['strategy']} · ${bestRow['tf']}',
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
            _col('TF', 'tf'),
            _col('Avg Sharpe', 'avg_oos_sharpe'),
            _col('Std', 'std_oos_sharpe'),
            _col('% Positive', 'pct_positive'),
            _col('Windows', 'windows'),
          ],
          rows: rows.map((r) {
            final sharpe = (r['avg_oos_sharpe'] ?? 0).toDouble();
            final std = (r['std_oos_sharpe'] ?? 0).toDouble();
            final pctPos = (r['pct_positive'] ?? 0).toDouble();
            final windows = (r['windows'] ?? 0) as int;
            return DataRow(cells: [
              DataCell(Text(r['symbol'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text(r['strategy'] ?? '')),
              DataCell(Text(r['tf'] ?? '')),
              DataCell(Text(sharpe.toStringAsFixed(2),
                  style: TextStyle(color: sharpe > 0 ? AppTheme.buy : AppTheme.sell, fontWeight: FontWeight.w700))),
              DataCell(Text(std.toStringAsFixed(2),
                  style: TextStyle(color: std > 1 ? AppTheme.warn : AppTheme.textSecondary))),
              DataCell(Text('${pctPos.toStringAsFixed(0)}%',
                  style: TextStyle(color: pctPos >= 50 ? AppTheme.buy : AppTheme.sell))),
              DataCell(Text('$windows')),
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
