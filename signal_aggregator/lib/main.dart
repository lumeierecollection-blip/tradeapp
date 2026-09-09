import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'journal/journal.dart';
import 'services/paper_trader.dart';
import 'services/storage.dart';
import 'state/app_state.dart';
import 'ui/app_shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = await Storage.load();
  final journal = Journal(storage);
  final paperTrader = PaperTrader(storage, journal: journal);
  final appState = AppState(storage, paperTrader, journal);
  await appState.initNotifications();
  await appState.initPush();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: appState),
        ChangeNotifierProvider<PaperTrader>.value(value: paperTrader),
        ChangeNotifierProvider<Journal>.value(value: journal),
      ],
      child: const SignalAggregatorApp(),
    ),
  );
}

class SignalAggregatorApp extends StatefulWidget {
  const SignalAggregatorApp({super.key});

  @override
  State<SignalAggregatorApp> createState() => _SignalAggregatorAppState();
}

class _SignalAggregatorAppState extends State<SignalAggregatorApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      appState.initNotifications();
      appState.notifications.requestPermission();
      appState.startTimer();
      appState.startBackgroundWorker();
      appState.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Signal Aggregator',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const AppShell(),
    );
  }
}
