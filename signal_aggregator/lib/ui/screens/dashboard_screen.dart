import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/validated_signal.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/buy_sell_times.dart';
import 'signal_detail_screen.dart';

class DashboardScreen extends StatelessWidget {
  final VoidCallback onSeeAll;

  const DashboardScreen({super.key, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final hero = _heroSignal(appState.validated);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: _GreetingTitle(),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: appState.isLoading ? null : appState.refresh,
            icon: const Icon(Icons.refresh),
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: appState.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            if (appState.isLoading) const _LoadingBar(),
            if (appState.error != null) _ErrorBanner(message: appState.error!),
            const SizedBox(height: 8),
            if (hero == null)
              _NoSignal(hasScanned: appState.lastUpdated != null, onRefresh: appState.refresh)
            else
              _SignalHero(vs: hero, onTap: () => _openDetail(context, hero)),
            const SizedBox(height: 16),
            _Footer(
              onSeeAll: onSeeAll,
              updated: appState.lastUpdated,
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, ValidatedSignal vs) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SignalDetailScreen(vs: vs)),
    );
  }

  /// The best signal that is still actionable; otherwise the freshest one.
  ValidatedSignal? _heroSignal(List<ValidatedSignal> all) {
    if (all.isEmpty) return null;
    final now = DateTime.now();
    for (final vs in all) {
      if (vs.sellAt.isAfter(now)) return vs;
    }
    return all.first;
  }
}

class _GreetingTitle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final h = DateTime.now().hour;
    final greeting = h < 5
        ? 'Up late'
        : h < 12
            ? 'Good morning'
            : h < 18
                ? 'Good afternoon'
                : 'Good evening';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 4),
        Text(greeting, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
        Text(
          'Here\u2019s your next move',
          style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _SignalHero extends StatelessWidget {
  final ValidatedSignal vs;
  final VoidCallback onTap;

  const _SignalHero({required this.vs, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.directionColor(vs.direction);
    final isBuy = vs.direction == Direction.buy;
    final now = DateTime.now();
    final status = vs.status(now);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.line),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.14),
            AppTheme.surfaceAlt,
            AppTheme.surfaceAlt,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'NEXT MOVE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${vs.probability.round()}% rightness',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      vs.direction.label,
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: color,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      vs.symbol,
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: AppTheme.textPrimary,
                        height: 1,
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            isBuy ? 'Target profit' : 'Target drop',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                          Text(
                            '${isBuy ? '+' : '−'}${vs.upsidePct.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 20),
                BuySellTimes(vs: vs, large: true),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: now.isBefore(vs.sellAt) ? color : AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        status,
                        style: const TextStyle(fontSize: 13.5, color: AppTheme.textSecondary),
                      ),
                    ),
                    Text(
                      'Why this signal?',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accent,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_right, size: 18, color: AppTheme.accent),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoSignal extends StatelessWidget {
  final bool hasScanned;
  final VoidCallback onRefresh;

  const _NoSignal({required this.hasScanned, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 56),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        children: [
          Icon(Icons.radar, size: 44, color: AppTheme.textMuted.withValues(alpha: 0.7)),
          const SizedBox(height: 18),
          const Text(
            'No signal right now',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            hasScanned
                ? 'Nothing is lining up yet. A signal appears when a post and the market agree.'
                : 'Tap refresh to scan Reddit, news and Telegram for a signal.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Scan now'),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final VoidCallback onSeeAll;
  final DateTime? updated;

  const _Footer({required this.onSeeAll, required this.updated});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TextButton(
          onPressed: onSeeAll,
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.textSecondary,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
          child: const Text('See all signals', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        const Spacer(),
        Text(
          updated == null ? 'Not scanned yet' : 'Updated ${AppTheme.timeAgo(updated!)}',
          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
      ],
    );
  }
}

class _LoadingBar extends StatelessWidget {
  const _LoadingBar();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 14),
      child: LinearProgressIndicator(
        minHeight: 2,
        borderRadius: BorderRadius.all(Radius.circular(2)),
        color: AppTheme.accent,
        backgroundColor: AppTheme.line,
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.sell.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.sell.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppTheme.sell, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
