import 'package:flutter/material.dart';

import 'screens/backtest_hub_screen.dart';
import 'screens/more_screen.dart';
import 'screens/portfolio_hub_screen.dart';
import 'screens/signals_hub_screen.dart';
import 'theme.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  void _changeTab(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    const pages = [
      SignalsHubScreen(),
      BacktestHubScreen(),
      PortfolioHubScreen(),
      MoreScreen(),
    ];

    // Signals (0) and Backtest (1) show numbers derived from delayed Yahoo data.
    final showBanner = _index <= 1;

    return Scaffold(
      // Same widget tree for every tab (empty slot, not a conditional child) so
      // switching tabs never recreates the pages and loses their state.
      body: Column(
        children: [
          showBanner ? const SafeArea(bottom: false, child: DataAccuracyBanner()) : const SizedBox.shrink(),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: showBanner, // the banner already cleared the status bar
              child: IndexedStack(index: _index, children: pages),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _changeTab,
              backgroundColor: const Color(0xFF121212),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.show_chart), label: 'Signals'),
                NavigationDestination(icon: Icon(Icons.analytics), label: 'Backtest'),
                NavigationDestination(icon: Icon(Icons.account_balance_wallet), label: 'Portfolio'),
                NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Always-visible disclaimer on the Signals and Backtest tabs.
class DataAccuracyBanner extends StatelessWidget {
  const DataAccuracyBanner({super.key});

  static const String message =
      '⚠️ Data Source: Yahoo Finance. Prices are delayed 15-20 minutes. '
      'Signals are for analysis, not for live trading.';

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('data_accuracy_banner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.sell.withValues(alpha: 0.15),
        border: Border(bottom: BorderSide(color: AppTheme.sell.withValues(alpha: 0.5))),
      ),
      child: const Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.sell, height: 1.3),
      ),
    );
  }
}
