import 'package:http/http.dart' as http;

import '../../models/signal.dart';
import '../symbols.dart';
import 'signal_source.dart';

class TelegramSource implements SignalSource {
  final List<String> channels;
  final http.Client _client = http.Client();

  TelegramSource({required this.channels});

  @override
  String get key => 'telegram';

  @override
  String get name => 'Telegram';

  @override
  bool get requiresSetup => true;

  @override
  Future<List<Signal>> fetch() async {
    final signals = <Signal>[];
    for (final channel in channels) {
      try {
        final uri = Uri.parse('https://t.me/s/$channel');
        final res = await _client.get(uri).timeout(const Duration(seconds: 25));
        if (res.statusCode != 200) continue;
        signals.addAll(_parseHtml(channel, res.body));
      } catch (_) {
        // Channel may be private or preview unavailable.
      }
    }
    return signals;
  }

  List<Signal> _parseHtml(String channel, String html) {
    final signals = <Signal>[];
    final regex = RegExp(
      r'<div class="tgme_widget_message[^"]*"[^>]*data-post="([^"]+)".*?'
      r'<div class="tgme_widget_message_text[^"]*"[^>]*>(.*?)</div>',
      dotAll: true,
    );
    for (final m in regex.allMatches(html)) {
      final rawText = _cleanHtml(m.group(2) ?? '');
      if (rawText.isEmpty) continue;
      final symbols = Symbols.extract(rawText);
      if (symbols.isEmpty) continue;
      signals.add(Signal(
        id: 'tg-${m.group(1) ?? '$channel-${signals.length}'}',
        sourceKey: key,
        sourceName: '@$channel',
        author: '@$channel',
        title: '',
        text: rawText,
        symbols: symbols,
        postedAt: DateTime.now(),
        url: 'https://t.me/${m.group(1) ?? channel}',
      ));
    }
    return signals;
  }

  String _cleanHtml(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
