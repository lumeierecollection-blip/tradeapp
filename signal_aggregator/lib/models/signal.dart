class Signal {
  final String id;
  final String sourceKey;
  final String sourceName;
  final String author;
  final String title;
  final String text;
  final List<String> symbols;
  final DateTime postedAt;
  final String url;

  const Signal({
    required this.id,
    required this.sourceKey,
    required this.sourceName,
    required this.author,
    required this.title,
    required this.text,
    required this.symbols,
    required this.postedAt,
    required this.url,
  });

  String get snippet {
    final full = title.isEmpty ? text : '$title\n\n$text';
    return full.trim();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourceKey': sourceKey,
        'sourceName': sourceName,
        'author': author,
        'title': title,
        'text': text,
        'symbols': symbols,
        'postedAt': postedAt.toIso8601String(),
        'url': url,
      };

  factory Signal.fromJson(Map<String, dynamic> json) => Signal(
        id: json['id'] as String,
        sourceKey: json['sourceKey'] as String,
        sourceName: json['sourceName'] as String,
        author: json['author'] as String? ?? '',
        title: json['title'] as String? ?? '',
        text: json['text'] as String? ?? '',
        symbols: (json['symbols'] as List<dynamic>? ?? []).cast<String>(),
        postedAt: DateTime.parse(json['postedAt'] as String),
        url: json['url'] as String? ?? '',
      );
}
