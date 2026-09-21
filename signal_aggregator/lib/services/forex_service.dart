import 'dart:convert';
import 'package:http/http.dart' as http;

class ForexService {
  static const List<String> defaultSymbols = [
    'EURUSD=X', 'GBPUSD=X', 'USDJPY=X', 'GC=F', 'AUDUSD=X',
  ];

  /// Yahoo Finance chart endpoint (no API key required)
  Future<double?> fetchRate(String symbol) async {
    final url = Uri.parse(
      'https://query1.finance.yahoo.com/v8/finance/chart/$symbol?interval=1h&range=1d',
    );
    try {
      final res = await http.get(url);
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      final result = data['chart']['result']?[0];
      final closes = result?['indicators']['quote']?[0]?['close'] as List?;
      if (closes == null || closes.isEmpty) return null;
      final last = closes.lastWhere((v) => v != null, orElse: () => null);
      return last == null ? null : (last as num).toDouble();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, double>> fetchAll([List<String>? symbols]) async {
    final list = symbols ?? defaultSymbols;
    final out = <String, double>{};
    for (final s in list) {
      final v = await fetchRate(s);
      if (v != null) out[s] = v;
    }
    return out;
  }
}
