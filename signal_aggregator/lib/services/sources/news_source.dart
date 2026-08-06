import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/signal.dart';
import '../symbols.dart';
import 'signal_source.dart';

class NewsSource implements SignalSource {
  final http.Client _client = http.Client();

  @override
  String get key => 'news';

  @override
  String get name => 'Crypto news';

  @override
  bool get requiresSetup => false;

  @override
  Future<List<Signal>> fetch() async {
    final signals = <Signal>[];
    try {
      final uri = Uri.parse('https://min-api.cryptocompare.com/data/v2/news/?lang=EN');
      final res = await _client.get(uri).timeout(const Duration(seconds: 25));
      if (res.statusCode != 200) return signals;
      final body = jsonDecode(res.body);
      final items = (body['Data'] as List<dynamic>? ?? []);
      for (final item in items) {
        final map = item as Map<String, dynamic>;
        final title = map['title'] as String? ?? '';
        final bodyText = _stripTags(map['body'] as String? ?? '');
        final text = '$title. $bodyText';
        final symbols = Symbols.extract(text);
        if (symbols.isEmpty) continue;
        final published = (map['published_on'] as num?)?.toInt() ?? 0;
        signals.add(Signal(
          id: 'news-${map['id']}',
          sourceKey: key,
          sourceName: (map['source_info'] as Map<String, dynamic>?)?['name'] as String? ?? 'News',
          author: '',
          title: title,
          text: bodyText,
          symbols: symbols,
          postedAt: published == 0
              ? DateTime.now()
              : DateTime.fromMillisecondsSinceEpoch(published * 1000),
          url: map['url'] as String? ?? '',
        ));
      }
    } catch (_) {
      // Ignore network errors; news is best-effort.
    }
    return signals;
  }

  String _stripTags(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
