import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:signal_aggregator/services/market_service.dart';

void main() {
  test('falls back to Yahoo Finance spot when Binance fails, marked stale', () async {
    final client = MockClient((req) async {
      if (req.url.host.contains('binance')) {
        return http.Response('down', 503);
      }
      // Yahoo Finance v8 chart response
      return http.Response(jsonEncode({
        'chart': {
          'result': [{'meta': {'regularMarketPrice': 123.45}}]
        }
      }), 200);
    });

    final snaps = await MarketService(client: client).fetchSnapshots(['BTC']);
    final btc = snaps['BTC'];

    expect(btc, isNotNull);
    expect(btc!.source, 'yahoo');
    expect(btc.stale, isTrue);
    expect(btc.price, closeTo(123.45, 1e-9));
    expect(btc.rsi14, 50); // neutralised
  });

  test('drops a symbol when both sources fail and nothing is cached', () async {
    final client = MockClient((req) async => http.Response('x', 500));
    final snaps = await MarketService(client: client).fetchSnapshots(['BTC']);
    expect(snaps.containsKey('BTC'), isFalse);
  });

  test('serves the cached fallback again within the TTL, still stale', () async {
    var calls = 0;
    final client = MockClient((req) async {
      calls++;
      if (req.url.host.contains('binance')) {
        return http.Response('down', 503);
      }
      return http.Response(jsonEncode({'data': {'amount': '99'}}), 200);
    });

    final svc = MarketService(client: client);
    await svc.fetchSnapshots(['BTC']);
    final after = calls;

    final again = await svc.fetchSnapshots(['BTC']);
    expect(calls, after); // no new HTTP inside the TTL
    expect(again['BTC']!.stale, isTrue);
  });
}
