import 'package:flutter/material.dart';

import '../widgets/hub_tabs.dart';
import 'backtest_screen.dart';
import 'signal_performance_screen.dart';

/// Backtest tab: [Matrix] walk-forward backtests, [Live Record] how logged
/// signals actually performed.
class BacktestHubScreen extends StatelessWidget {
  const BacktestHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const HubTabs(
      labels: ['Matrix', 'Live Record'],
      children: [BacktestScreen(), SignalPerformanceScreen()],
    );
  }
}
