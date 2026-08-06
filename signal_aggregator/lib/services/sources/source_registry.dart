import '../../models/signal.dart';
import 'market_pulse_source.dart';
import 'news_source.dart';
import 'reddit_source.dart';
import 'rss_news_source.dart';
import 'signal_source.dart';
import 'telegram_source.dart';

class SourceRegistry {
  final List<SignalSource> _sources;

  SourceRegistry({List<String> telegramChannels = const []})
      : _sources = [
          RedditSource(),
          NewsSource(),
          RssNewsSource(),
          TelegramSource(channels: telegramChannels),
          const MarketPulseSource(),
        ];

  List<SignalSource> get all => List.unmodifiable(_sources);

  List<SignalSource> enabled(bool Function(SignalSource) isEnabled) =>
      _sources.where(isEnabled).toList();

  Future<List<Signal>> fetchAll(List<SignalSource> active) async {
    final results = await Future.wait(active.map((s) => s.fetch()));
    final seen = <String>{};
    final signals = <Signal>[];
    for (final batch in results) {
      for (final signal in batch) {
        if (seen.add(signal.id)) signals.add(signal);
      }
    }
    signals.sort((a, b) => b.postedAt.compareTo(a.postedAt));
    return signals;
  }

  void refreshChannels(List<String> channels) {
    _sources[_sources.indexWhere((s) => s is TelegramSource)] =
        TelegramSource(channels: channels);
  }
}
