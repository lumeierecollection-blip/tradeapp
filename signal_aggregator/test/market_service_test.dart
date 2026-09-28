import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:signal_aggregator/services/market_service.dart';

/// A Yahoo v8 chart payload of [n] bars spaced [step] apart, all ending at the
/// same instant (like live data), closes rising by 1.
String chart(int n, Duration step, {double start = 100}) {
  final tEnd = DateTime.utc(2026, 9, 28).millisecondsSinceEpoch ~/ 1000;
  final ts = [for (var i = 0; i < n; i++) tEnd - (n - 1 - i) * step.inSeconds];
  final closes = [for (var i = 0; i < n; i++) start + i];
  return jsonEncode({
    'chart': {
      'result': [
        {
          'meta': {'regularMarketPrice': closes.last},
          'timestamp': ts,
          'indicators': {
            'quote': [
              {
                'high': [for (final c in closes) c + 0.5],
                'low': [for (final c in closes) c - 0.5],
                'close': closes,
                'volume': [for (var i = 0; i < n; i++) 10],
              }
            ]
          }
        }
      ]
    }
  });
}

void main() {
  test('builds a full snapshot from Yahoo 1h + 5m bars', () async {
    final seen = <Uri>[];
    final client = MockClient((req) async {
      seen.add(req.url);
      expect(req.headers['User-Agent'], isNotNull); // Yahoo 429s without one
      final interval = req.url.queryParameters['interval'];
      if (interval == '1h') return http.Response(chart(48, const Duration(hours: 1)), 200);
      return http.Response(chart(24, const Duration(minutes: 5), start: 147), 200);
    });

    final snaps = await MarketService(client: client).fetchSnapshots(['BTC']);
    final btc = snaps['BTC']!;

    expect(seen.every((u) => u.path.endsWith('/BTC-USD')), isTrue);
    expect(btc.source, 'yahoo');
    expect(btc.stale, isFalse);
    expect(btc.price, 170); // last 5m close
    expect(btc.rsi14, 100); // strictly rising closes
    expect(btc.change5m, greaterThan(0));
    expect(btc.change1h, greaterThan(0));
    expect(btc.atrPct, greaterThan(0));
    expect(btc.resistance, greaterThan(btc.support));
  });

  test('encodes index/FX tickers and skips symbols outside the universe', () async {
    final paths = <String>[];
    final client = MockClient((req) async {
      paths.add(req.url.toString());
      return http.Response(chart(48, const Duration(hours: 1)), 200);
    });

    final snaps = await MarketService(client: client).fetchSnapshots(['^GSPC', 'EURUSD=X', 'XRP']);

    expect(snaps.keys, containsAll(['^GSPC', 'EURUSD=X']));
    expect(snaps.containsKey('XRP'), isFalse);
    expect(paths.any((p) => p.contains('%5EGSPC')), isTrue);
    expect(paths.any((p) => p.contains('EURUSD%3DX')), isTrue);
  });

  test('falls back to chart meta price when bars fail, marked stale', () async {
    final client = MockClient((req) async {
      if (req.url.queryParameters['interval'] == '1d') {
        return http.Response(jsonEncode({
          'chart': {
            'result': [
              {'meta': {'regularMarketPrice': 123.45}}
            ]
          }
        }), 200);
      }
      return http.Response('down', 503);
    });

    final btc = (await MarketService(client: client).fetchSnapshots(['BTC']))['BTC']!;

    expect(btc.source, 'yahoo-spot');
    expect(btc.stale, isTrue);
    expect(btc.price, closeTo(123.45, 1e-9));
    expect(btc.rsi14, 50); // neutralised
  });

  test('drops a symbol when every request fails and nothing is cached', () async {
    final client = MockClient((req) async => http.Response('x', 500));
    final snaps = await MarketService(client: client).fetchSnapshots(['BTC']);
    expect(snaps.containsKey('BTC'), isFalse);
  });

  test('serves the cached snapshot within the TTL without new HTTP', () async {
    var calls = 0;
    final client = MockClient((req) async {
      calls++;
      return http.Response(chart(48, const Duration(hours: 1)), 200);
    });

    final svc = MarketService(client: client);
    await svc.fetchSnapshots(['ETH']);
    final after = calls;

    final again = await svc.fetchSnapshots(['ETH']);
    expect(calls, after);
    expect(again['ETH'], isNotNull);
  });
}
