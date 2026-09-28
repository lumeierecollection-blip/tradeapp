import 'package:flutter/material.dart';

import 'screens/backtest_screen.dart';
import 'screens/more_screen.dart';
import 'screens/portfolio_hub_screen.dart';
import 'screens/signals_hub_screen.dart';

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
      BacktestScreen(),
      PortfolioHubScreen(),
      MoreScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
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
