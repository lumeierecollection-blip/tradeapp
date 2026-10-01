import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:signal_aggregator/services/github_data_service.dart';
import 'package:signal_aggregator/services/historical_price_service.dart';
import 'package:signal_aggregator/services/signal_performance.dart';
import 'package:signal_aggregator/ui/app_shell.dart';
import 'package:signal_aggregator/ui/screens/signal_performance_screen.dart';

PriceBar bar(String day, double close) => PriceBar(DateTime.parse('${day}T00:00:00Z'), close);

Map<String, dynamic> sig(String symbol, String signal, double price, String at) =>
    {'symbol': symbol, 'signal': signal, 'confidence': 0.6, 'price': price, 'generated_at': at};

void main() {
  final now = DateTime.utc(2026, 9, 20, 12);

  test('parseHistory keeps BUY/SELL only and skips junk', () {
    final out = SignalPerformance.parseHistory([
      {
        'timestamp': '2026-09-10T06:00:00Z',
        'signals': [
          sig('A', 'BUY', 1.0, '2026-09-10T06:00:01Z'),
          sig('B', 'HOLD', 1.0, '2026-09-10T06:00:01Z'),
          sig('C', 'SELL', 0.0, '2026-09-10T06:00:01Z'), // errored row
          {'symbol': 'D', 'signal': 'sell', 'price': 2.0}, // falls back to run timestamp
          'junk',
        ],
      },
      'junk',
      {'timestamp': 'x', 'signals': 5},
    ]);
    expect(out.map((s) => s.symbol), ['A', 'D']);
    expect(out[1].direction, 'SELL');
    expect(out[1].generatedAt, DateTime.utc(2026, 9, 10, 6));
  });

  test('evaluate scores direction, win rate and averages', () {
    final signals = SignalPerformance.parseHistory([
      {
        'timestamp': '2026-09-10T06:00:00Z',
        'signals': [
          sig('UP', 'BUY', 100, '2026-09-10T06:00:00Z'), // 110 -> +10 win
          sig('DN', 'SELL', 100, '2026-09-10T06:00:00Z'), // 95 -> +5 win
          sig('BAD', 'BUY', 100, '2026-09-10T06:00:00Z'), // 90 -> -10 loss
          sig('NEW', 'BUY', 100, '2026-09-19T06:00:00Z'), // exit bar is today -> pending
        ],
      },
    ]);
    final bars = {
      'UP': [bar('2026-09-11', 110)],
      'DN': [bar('2026-09-11', 95)],
      'BAD': [bar('2026-09-11', 90)],
      'NEW': [bar('2026-09-20', 120)],
    };
    final s = SignalPerformance.evaluate(signals, bars, const Duration(days: 1), now: now);
    expect(s.scoredCount, 3);
    expect(s.pending, 1);
    expect(s.winRate, closeTo(66.67, 0.01));
    expect(s.avgWin, closeTo(7.5, 1e-9));
    expect(s.avgLoss, closeTo(-10, 1e-9));
  });

  test('exit uses first bar on/after target, skipping weekends; missing bars stay pending', () {
    final signals = SignalPerformance.parseHistory([
      {'timestamp': '2026-09-11T06:00:00Z', 'signals': [sig('X', 'BUY', 100, '2026-09-11T06:00:00Z'), sig('Y', 'BUY', 100, '2026-09-11T06:00:00Z')]},
    ]);
    final s = SignalPerformance.evaluate(
      signals,
      {'X': [bar('2026-09-11', 99), bar('2026-09-14', 101)]},
      const Duration(days: 1),
      now: now,
    );
    expect(s.results[0].exitPrice, 101);
    expect(s.results[0].outcome, Outcome.win);
    expect(s.results[1].outcome, Outcome.pending);
    expect(s.winRate, 100);
  });

  test('empty summary has null metrics', () {
    final s = SignalPerformance.evaluate([], {}, const Duration(days: 1));
    expect(s.winRate, isNull);
    expect(s.avgWin, isNull);
    expect(s.avgLoss, isNull);
  });

  testWidgets('performance screen shows metrics and rows', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SignalPerformanceScreen(data: _FakeData(), prices: _FakePrices()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Win rate'), findsOneWidget);
    expect(find.text('100.0%'), findsOneWidget);
    expect(find.text('WIN'), findsOneWidget);
    expect(find.textContaining('far too few'), findsOneWidget);
  });

  testWidgets('performance screen shows empty state without history', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SignalPerformanceScreen(data: _EmptyData(), prices: _FakePrices()),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('No signal history yet'), findsOneWidget);
  });

  testWidgets('data accuracy banner shows the required text', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: DataAccuracyBanner())));
    expect(
      find.text('⚠️ Data Source: Yahoo Finance. Prices are delayed 15-20 minutes. '
          'Signals are for analysis, not for live trading.'),
      findsOneWidget,
    );
  });
}

class _FakeData extends GithubDataService {
  @override
  Future<List<dynamic>> getSignalHistory({bool force = false}) async => [
        {
          'timestamp': '2026-09-01T06:00:00Z',
          'signals': [sig('EURUSD=X', 'BUY', 1.10, '2026-09-01T06:00:00Z')],
        },
      ];
}

class _EmptyData extends GithubDataService {
  @override
  Future<List<dynamic>> getSignalHistory({bool force = false}) async => [];
}

class _FakePrices extends HistoricalPriceService {
  @override
  Future<List<PriceBar>> getDailyBars(String symbol, {String range = '1y'}) async =>
      [bar('2026-09-02', 1.12)];
}
