import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/market_snapshot.dart';
import '../models/signal.dart';
import '../models/validated_signal.dart';

class CloudResult {
  final DateTime generatedAt;
  final List<Signal> signals;
  final List<ValidatedSignal> validated;
  final Map<String, MarketSnapshot> markets;

  const CloudResult({
    required this.generatedAt,
    required this.signals,
    required this.validated,
    required this.markets,
  });
}

class CloudBackend {
  final String baseUrl;
  final http.Client _client = http.Client();

  CloudBackend({required this.baseUrl});

  static String normalize(String input) {
    var url = input.trim();
    if (url.isEmpty) return url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    return url.replaceAll(RegExp(r'/+$'), '');
  }

  Future<CloudResult> fetchSignals() async {
    if (baseUrl.trim().isEmpty) {
      throw Exception('Cloud backend URL is not set.');
    }
    final uri = Uri.parse('$baseUrl/api/signals');
    final res = await _client.get(uri).timeout(const Duration(seconds: 120));
    if (res.statusCode != 200) {
      throw Exception('Cloud backend ${res.statusCode}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return CloudResult(
      generatedAt:
          DateTime.tryParse(body['generatedAt'] as String? ?? '') ?? DateTime.now(),
      signals: (body['signals'] as List<dynamic>? ?? [])
          .map((e) => Signal.fromJson(e as Map<String, dynamic>))
          .toList(),
      validated: (body['validated'] as List<dynamic>? ?? [])
          .map((e) => ValidatedSignal.fromJson(e as Map<String, dynamic>))
          .toList(),
      markets: (body['markets'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(k, MarketSnapshot.fromJson(v as Map<String, dynamic>)),
      ),
    );
  }

  Future<bool> registerDevice(String token) async {
    final uri = Uri.parse('$baseUrl/api/device/register');
    final res = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'token': token}),
        )
        .timeout(const Duration(seconds: 30));
    return res.statusCode == 200;
  }

  Future<bool> unregisterDevice(String token) async {
    final uri = Uri.parse('$baseUrl/api/device/unregister');
    final res = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'token': token}),
        )
        .timeout(const Duration(seconds: 30));
    return res.statusCode == 200;
  }

  void dispose() => _client.close();
}
