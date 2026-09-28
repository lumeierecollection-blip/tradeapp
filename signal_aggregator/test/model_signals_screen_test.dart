import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:signal_aggregator/services/github_data_service.dart';
import 'package:signal_aggregator/ui/screens/model_signals_screen.dart';

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

/// The real files the workflows commit — not hand-written fixtures.
Map<String, dynamic> _real(String name) =>
    jsonDecode(File('data/signals/$name').readAsStringSync()) as Map<String, dynamic>;

Widget _app(GithubDataService data) =>
    MaterialApp(home: ModelSignalsScreen(data: data));

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
}
