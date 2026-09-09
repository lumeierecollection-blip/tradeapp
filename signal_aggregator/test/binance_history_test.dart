import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:signal_aggregator/backtesting/binance_history.dart';

List<Object> _kline(int t, String o, String h, String l, String c, String v) =>
    [t, o, h, l, c, v, 0, '0', 0, '0', '0', '0'];

void main() {
  test('maps a bare ticker to a USDT pair and parses klines oldest-first', () async {
    var symbolParam = '';
    var intervalParam = '';
    var limitParam = '';
    final client = MockClient((req) async {
      symbolParam = req.url.queryParameters['symbol'] ?? '';
      intervalParam = req.url.queryParameters['interval'] ?? '';
      limitParam = req.url.queryParameters['limit'] ?? '';
      return http.Response(
        jsonEncode([
          _kline(1700000000000, '100.0', '110.0', '95.0', '105.0', '12.5'),
          _kline(1700003600000, '105.0', '108.0', '101.0', '102.0', '9.0'),
        ]),
        200,
      );
    });

    final bars = await BinanceHistory(client: client)
        .fetch(symbol: 'btc', interval: '1h', limit: 2);

    expect(symbolParam, 'BTCUSDT');
    expect(intervalParam, '1h');
    expect(limitParam, '2');
    expect(bars, hasLength(2));
    expect(bars.first.open, 100.0);
    expect(bars.first.high, 110.0);
    expect(bars.first.low, 95.0);
    expect(bars.last.close, 102.0);
    expect(bars.last.volume, 9.0);
  });

  test('leaves an explicit USDT pair untouched and clamps the limit', () async {
    var symbolParam = '';
    var limitParam = '';
    final client = MockClient((req) async {
      symbolParam = req.url.queryParameters['symbol'] ?? '';
      limitParam = req.url.queryParameters['limit'] ?? '';
      return http.Response('[]', 200);
    });

    await BinanceHistory(client: client)
        .fetch(symbol: 'ETHUSDT', interval: '1d', limit: 5000);

    expect(symbolParam, 'ETHUSDT');
    expect(limitParam, '1000');
  });

  test('throws BinanceHistoryException on a non-200', () async {
    final client = MockClient((req) async => http.Response('nope', 418));
    expect(
      () => BinanceHistory(client: client).fetch(symbol: 'ETH'),
      throwsA(isA<BinanceHistoryException>()),
    );
  });
}
