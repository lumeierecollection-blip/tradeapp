import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:signal_aggregator/services/github_data_service.dart';
import 'package:signal_aggregator/services/price_history_service.dart';
import 'package:signal_aggregator/ui/screens/model_signals_screen.dart';
import 'package:signal_aggregator/ui/screens/signal_detail_screen.dart';

/// Serves fixed payloads instead of hitting GitHub. `{}` mirrors what the real
/// service returns on a 404 / network failure.
class _FakeData extends GithubDataService {
  Map<String, dynamic> ml;
  Map<String, dynamic> rules;
  Completer<void>? gate;
  int calls = 0;

  _FakeData({this.ml = const {}, this.rules = const {}, this.gate});

  @override
  Future<Map<String, dynamic>> getMlSignals({bool force = false}) async {
    calls++;
    await gate?.future;
    return ml;
  }

  @override
  Future<Map<String, dynamic>> getLatestSignals({bool force = false}) async {
    await gate?.future;
    return rules;
  }
}

/// Price history without Yahoo. [closes] empty mimics a failed fetch.
class _FakeHistory extends PriceHistoryService {
  final List<double> closes;
  final requested = <String>[];
  _FakeHistory([this.closes = const [1.10, 1.12, 1.11, 1.13, 1.14]]);

  @override
  Future<List<double>> getPriceHistory(String symbol, {int days = 30}) async {
    requested.add('$symbol|$days');
    return closes;
  }
}

/// The real files the workflows commit — not hand-written fixtures.
Map<String, dynamic> _real(String name) =>
    jsonDecode(File('data/signals/$name').readAsStringSync()) as Map<String, dynamic>;

Widget _app(GithubDataService data, {PriceHistoryService? history}) =>
    MaterialApp(home: ModelSignalsScreen(data: data, priceHistory: history ?? _FakeHistory()));

Map<String, dynamic> _two() => {
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'signals': [
        {'symbol': 'EURUSD=X', 'signal': 'BUY', 'confidence': 0.8, 'price': 1.13766, 'regime': 'trend'},
        {'symbol': '^GSPC', 'signal': 'SELL', 'confidence': 0.4, 'price': 7705.0, 'regime': 'range'},
      ],
    };

void main() {
  testWidgets('loading → data from the real ml_latest.json', (tester) async {
    final gate = Completer<void>();
    final ml = _real('ml_latest.json');
    final fake = _FakeData(ml: ml, rules: _real('latest.json'), gate: gate);

    await tester.pumpWidget(_app(fake));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();

    final first = (ml['signals'] as List).first as Map<String, dynamic>;
    expect(find.text('Model Signals'), findsOneWidget);
    expect(find.textContaining('ML model (LightGBM)'), findsOneWidget);
    expect(find.text(first['symbol'] as String), findsWidgets);
    expect(find.text('${((first['confidence'] as num) * 100).round()}%'), findsWidgets);
    expect(find.text(first['regime'] as String), findsWidgets);
    expect(find.textContaining('All (${(ml['signals'] as List).length})'), findsOneWidget);
    expect(find.textContaining('Not financial advice'), findsOneWidget);
  });

  testWidgets('falls back to the real latest.json when ML is empty', (tester) async {
    final rules = _real('latest.json');
    await tester.pumpWidget(_app(_FakeData(ml: {'signals': []}, rules: rules)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Rule-based'), findsOneWidget);
    final first = (rules['signals'] as List).first as Map<String, dynamic>;
    expect(find.text(first['symbol'] as String), findsWidgets);
  });

  testWidgets('filter chips narrow the list', (tester) async {
    await tester.pumpWidget(_app(_FakeData(ml: {
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'signals': [
        {'symbol': 'EURUSD=X', 'signal': 'BUY', 'confidence': 0.8, 'price': 1.13766, 'regime': 'trend'},
        {'symbol': '^GSPC', 'signal': 'SELL', 'confidence': 0.4, 'price': 7705.0, 'regime': 'range'},
      ],
    })));
    await tester.pumpAndSettle();

    expect(find.text('EURUSD=X'), findsOneWidget);
    expect(find.text('1.13766'), findsOneWidget);
    expect(find.text('7705.00'), findsOneWidget);

    await tester.tap(find.textContaining('SELL ('));
    await tester.pumpAndSettle();
    expect(find.text('EURUSD=X'), findsNothing);
    expect(find.text('^GSPC'), findsOneWidget);
  });

  testWidgets('empty state when the files load with no signals', (tester) async {
    await tester.pumpWidget(_app(_FakeData(ml: {'signals': []}, rules: {'signals': []})));
    await tester.pumpAndSettle();
    expect(find.text('No signals yet. Workflows run every 4 hours.'), findsOneWidget);
  });

  testWidgets('error state on network failure, retry refetches', (tester) async {
    final fake = _FakeData(); // both {} — what the service returns on failure
    await tester.pumpWidget(_app(fake));
    await tester.pumpAndSettle();

    expect(find.text('Could not load signals. Tap to retry.'), findsOneWidget);
    final before = fake.calls;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(fake.calls, before + 1);
  });

  testWidgets('each card renders a 30-day sparkline', (tester) async {
    final history = _FakeHistory();
    await tester.pumpWidget(_app(_FakeData(ml: _two()), history: history));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('price-chart')), findsNWidgets(2));
    expect(history.requested, containsAll(['EURUSD=X|30', '^GSPC|30']));
  });

  testWidgets('failed price fetch shows a grey placeholder, not an error', (tester) async {
    await tester.pumpWidget(_app(_FakeData(ml: _two()), history: _FakeHistory(const [])));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('price-chart')), findsNothing);
    expect(find.byKey(const ValueKey('price-chart-placeholder')), findsNWidgets(2));
    expect(find.text('EURUSD=X'), findsOneWidget);
  });

  testWidgets('tapping a card opens the detail screen with a 90-day chart', (tester) async {
    final history = _FakeHistory();
    await tester.pumpWidget(_app(_FakeData(ml: _two()), history: history));
    await tester.pumpAndSettle();

    await tester.tap(find.text('EURUSD=X'));
    await tester.pumpAndSettle();

    expect(find.byType(SignalDetailScreen), findsOneWidget);
    expect(find.text('90-day daily close'), findsOneWidget);
    expect(find.text('All fields'), findsOneWidget);
    expect(history.requested, contains('EURUSD=X|90'));

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(SignalDetailScreen), findsNothing);
  });

  testWidgets('auto-refresh timer fires every interval and stops on dispose', (tester) async {
    final fake = _FakeData(ml: _two());
    await tester.pumpWidget(_app(fake));
    await tester.pumpAndSettle();
    expect(fake.calls, 1);
    expect(find.textContaining('Auto-refresh every 60s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 60));
    await tester.pumpAndSettle();
    expect(fake.calls, 2);
    // Silent refresh keeps the list on screen.
    expect(find.text('EURUSD=X'), findsOneWidget);

    await tester.pump(const Duration(seconds: 60));
    await tester.pumpAndSettle();
    expect(fake.calls, 3);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 5));
    expect(fake.calls, 3);
  });

  testWidgets('Refresh now fetches immediately and restarts the countdown', (tester) async {
    final fake = _FakeData(ml: _two());
    await tester.pumpWidget(_app(fake));
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 40));
    await tester.tap(find.text('Refresh now'));
    await tester.pumpAndSettle();
    expect(fake.calls, 2);

    // Old timer would have fired at 60s; the restarted one fires 60s after the tap.
    await tester.pump(const Duration(seconds: 30));
    expect(fake.calls, 2);
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(fake.calls, 3);
  });
}
