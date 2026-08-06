import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/validated_signal.dart';
import '../../state/app_state.dart';
import '../widgets/signal_card.dart';
import 'signal_detail_screen.dart';

class SignalsScreen extends StatefulWidget {
  const SignalsScreen({super.key});

  @override
  State<SignalsScreen> createState() => _SignalsScreenState();
}

class _SignalsScreenState extends State<SignalsScreen> {
  Direction? _filter;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final all = appState.validated;
    final filtered = _filter == null ? all : all.where((v) => v.direction == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Signals'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: appState.isLoading ? null : appState.refresh,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<Direction?>(
                segments: const [
                  ButtonSegment(value: null, label: Text('All'), icon: Icon(Icons.all_inclusive, size: 18)),
                  ButtonSegment(value: Direction.buy, label: Text('Buy'), icon: Icon(Icons.trending_up, size: 18)),
                  ButtonSegment(value: Direction.sell, label: Text('Sell'), icon: Icon(Icons.trending_down, size: 18)),
                ],
                selected: {_filter},
                onSelectionChanged: (s) => setState(() => _filter = s.first),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: appState.refresh,
              child: filtered.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 120),
                        EmptyState(
                          icon: Icons.search_off,
                          title: 'No signals found',
                          message: 'No ${_filter?.label.toLowerCase() ?? ''} signals right now. '
                              'Signals appear when a post talks about a coin AND the market agrees.',
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final vs = filtered[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SignalCard(
                            vs: vs,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => SignalDetailScreen(vs: vs)),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
