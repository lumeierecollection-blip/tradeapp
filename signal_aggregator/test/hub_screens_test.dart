import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:signal_aggregator/journal/journal.dart';
import 'package:signal_aggregator/services/github_data_service.dart';
import 'package:signal_aggregator/services/paper_trader.dart';
import 'package:signal_aggregator/services/price_history_service.dart';
import 'package:signal_aggregator/services/storage.dart';
import 'package:signal_aggregator/state/app_state.dart';
import 'package:signal_aggregator/ui/screens/model_signals_screen.dart';
import 'package:signal_aggregator/ui/screens/more_screen.dart';
import 'package:signal_aggregator/ui/screens/review_screen.dart';
import 'package:signal_aggregator/ui/screens/settings_screen.dart';
import 'package:signal_aggregator/ui/screens/signals_hub_screen.dart';
import 'package:signal_aggregator/ui/screens/signals_screen.dart';

class _FakeData extends GithubDataService {
  int calls = 0;
  @override
  Future<Map<String, dynamic>> getMlSignals({bool force = false}) async {
    calls++;
    return {
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'signals': [
        {'symbol': 'EURUSD=X', 'signal': 'BUY', 'confidence': 0.8, 'price': 1.1377, 'regime': 'trend'},
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> getLatestSignals({bool force = false}) async => {};
}

class _FakeHistory extends PriceHistoryService {
  @override
  Future<List<double>> getPriceHistory(String symbol, {int days = 30}) async => [1.1, 1.2, 1.15];
}

/// The real providers main.dart wires up, on mock SharedPreferences.
Future<Widget> _withProviders(Widget home) async {
  SharedPreferences.setMockInitialValues({});
  final storage = await Storage.load();
  final journal = Journal(storage);
  final trader = PaperTrader(storage, journal: journal);
  final appState = AppState(storage, trader, journal);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppState>.value(value: appState),
      ChangeNotifierProvider<PaperTrader>.value(value: trader),
      ChangeNotifierProvider<Journal>.value(value: journal),
    ],
    child: MaterialApp(home: home),
  );
}

void main() {
  testWidgets('Signals hub opens on Model and switches to the real Live screen', (tester) async {
    final fake = _FakeData();
    await tester.pumpWidget(await _withProviders(SignalsHubScreen(
      model: ModelSignalsScreen(data: fake, priceHistory: _FakeHistory()),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Model Signals'), findsOneWidget);
    expect(find.text('EURUSD=X'), findsOneWidget);

    await tester.tap(find.text('Live'));
    await tester.pumpAndSettle();
    expect(find.byType(SignalsScreen), findsOneWidget);
    expect(find.text('Signals'), findsOneWidget); // Live screen's own AppBar

    // Back to Model: kept alive, so no reload.
    await tester.tap(find.text('Model'));
    await tester.pumpAndSettle();
    expect(find.text('EURUSD=X'), findsOneWidget);
    expect(fake.calls, 1);
  });

  testWidgets('More screen links to Review and Settings', (tester) async {
    await tester.pumpWidget(await _withProviders(const MoreScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(find.byType(ReviewScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  });
}
