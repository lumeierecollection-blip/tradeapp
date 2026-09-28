import 'package:flutter/material.dart';

import '../widgets/hub_tabs.dart';
import 'goals_screen.dart';
import 'portfolio_screen.dart';

/// Portfolio tab: [Holdings] paper-trading portfolio, [Goals] weekly plan.
class PortfolioHubScreen extends StatelessWidget {
  const PortfolioHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const HubTabs(
      labels: ['Holdings', 'Goals'],
      children: [PortfolioScreen(), GoalsScreen()],
    );
  }
}
