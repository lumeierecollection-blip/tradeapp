import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/signal.dart';
import '../symbols.dart';
import 'signal_source.dart';

class RedditSource implements SignalSource {
  static const List<String> subs = [
    'CryptoCurrency',
    'CryptoMarkets',
    'altcoin',
    'Bitcoin',
    'ethtrader',
  ];

  final http.Client _client = http.Client();

  @override
  String get key => 'reddit';

  @override
  String get name => 'Reddit';

  @override
  bool get requiresSetup => false;

  @override
  Future<List<Signal>> fetch() async {
    final signals = <Signal>[];
    for (final sub in subs) {
      try {
        final uri = Uri.parse('https://www.reddit.com/r/$sub/new.json?limit=20');
        final res = await _client
            .get(uri, headers: {
              'User-Agent': 'signal-aggregator-android/1.0 (learning tool)',
            })
            .timeout(const Duration(seconds: 25));
        if (res.statusCode != 200) continue;
        final body = jsonDecode(res.body);
        final children = (body['data']?['children'] as List<dynamic>? ?? []);
        for (final child in children) {
          final post = (child as Map<String, dynamic>)['data'] as Map<String, dynamic>;
          final title = post['title'] as String? ?? '';
          final selftext = post['selftext'] as String? ?? '';
          final text = '$title $selftext';
          final symbols = Symbols.extract(text);
          if (symbols.isEmpty) continue;
          final created = (post['created_utc'] as num?)?.toInt() ?? 0;
          signals.add(Signal(
            id: 'reddit-${post['id']}',
            sourceKey: key,
            sourceName: 'r/$sub',
            author: post['author'] as String? ?? '',
            title: title,
            text: selftext,
            symbols: symbols,
            postedAt: created == 0
                ? DateTime.now()
                : DateTime.fromMillisecondsSinceEpoch(created * 1000),
            url: 'https://www.reddit.com${post['permalink'] ?? ''}',
          ));
        }
      } catch (_) {
        // Skip failing subreddits silently.
      }
    }
    return signals;
  }
}
