import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../../models/signal.dart';
import '../symbols.dart';
import 'signal_source.dart';

/// Second free news feed (CoinDesk RSS) so altcoins beyond Bitcoin get more
/// headlines to build signals from.
class RssNewsSource implements SignalSource {
  static const String feedUrl =
      'https://www.coindesk.com/arc/outboundfeeds/rss/?outputType=xml';

  final http.Client _client = http.Client();

  @override
  String get key => 'rss';

  @override
  String get name => 'CoinDesk news';

  @override
  bool get requiresSetup => false;

  @override
  Future<List<Signal>> fetch() async {
    final signals = <Signal>[];
    try {
      final res = await _client.get(Uri.parse(feedUrl)).timeout(const Duration(seconds: 25));
      if (res.statusCode != 200) return signals;
      final doc = XmlDocument.parse(utf8.decode(res.bodyBytes));
      for (final item in doc.findAllElements('item')) {
        final title = _text(item, 'title');
        final description = _stripTags(_text(item, 'description'));
        final text = '$title. $description';
        final symbols = Symbols.extract(text);
        if (symbols.isEmpty) continue;

        final link = _text(item, 'link');
        final guid = _text(item, 'guid').isEmpty ? link : _text(item, 'guid');
        final published = _parseDate(_text(item, 'pubDate'));
        signals.add(Signal(
          id: 'rss-${_hashCode(guid)}',
          sourceKey: key,
          sourceName: name,
          author: '',
          title: title,
          text: description,
          symbols: symbols,
          postedAt: published,
          url: link,
        ));
      }
    } catch (_) {
      // RSS is best-effort; a bad feed must never break the scan.
    }
    return signals;
  }

  String _text(XmlElement item, String tag) {
    final el = item.getElement(tag);
    if (el == null) return '';
    return el.innerText.trim();
  }

  String _stripTags(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  DateTime _parseDate(String raw) {
    if (raw.isEmpty) return DateTime.now();
    try {
      return HttpDate.parse(raw);
    } catch (_) {
      return DateTime.tryParse(raw) ?? DateTime.now();
    }
  }

  int _hashCode(String s) => s.hashCode & 0x7FFFFFFF;
}
