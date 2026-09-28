import 'package:flutter/material.dart';

import '../widgets/hub_tabs.dart';
import 'model_signals_screen.dart';
import 'signals_screen.dart';

/// Signals tab: [Model] GitHub-published model signals, [Live] validated live
/// signals from AppState.
class SignalsHubScreen extends StatelessWidget {
  final Widget? model;
  final Widget? live;

  const SignalsHubScreen({super.key, this.model, this.live});

  @override
  Widget build(BuildContext context) {
    return HubTabs(
      labels: const ['Model', 'Live'],
      children: [
        model ?? const ModelSignalsScreen(),
        live ?? const SignalsScreen(),
      ],
    );
  }
}
