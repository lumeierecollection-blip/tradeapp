class MarketSnapshot {
  final String symbol;
  final double price;
  final double change5m;
  final double change15m;
  final double change1h;
  final double change24h;
  final double rsi14;
  final double volume24h;
  final double avgVolume;
  final double support;
  final double resistance;

  /// Average True Range (14) over recent 1h candles, as % of price. How much
  /// the market actually swings, used to judge whether a target is reachable.
  final double atrPct;

  /// Average volume of the most recent ~6 hours vs the 24h baseline. Spiking
  /// volume confirms a move is real; shrinking volume signals it is fading.
  final double recentVolumeRatio;

  final DateTime at;

  const MarketSnapshot({
    required this.symbol,
    required this.price,
    required this.change5m,
    required this.change15m,
    required this.change1h,
    required this.change24h,
    required this.rsi14,
    required this.volume24h,
    required this.avgVolume,
    required this.support,
    required this.resistance,
    this.atrPct = 0,
    this.recentVolumeRatio = 1.0,
    required this.at,
  });

  double get volumeRatio => avgVolume <= 0 ? 1.0 : volume24h / avgVolume;

  double get distanceToSupport => support <= 0 ? 1.0 : (price - support) / price;
  double get distanceToResistance => resistance <= 0 ? 1.0 : (resistance - price) / price;

  bool get nearSupport => distanceToSupport < 0.02;
  bool get nearResistance => distanceToResistance < 0.02;

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'price': price,
        'change5m': change5m,
        'change15m': change15m,
        'change1h': change1h,
        'change24h': change24h,
        'rsi14': rsi14,
        'volume24h': volume24h,
        'avgVolume': avgVolume,
        'support': support,
        'resistance': resistance,
        'atrPct': atrPct,
        'recentVolumeRatio': recentVolumeRatio,
        'at': at.toIso8601String(),
      };

  factory MarketSnapshot.fromJson(Map<String, dynamic> json) => MarketSnapshot(
        symbol: json['symbol'] as String,
        price: (json['price'] as num).toDouble(),
        change5m: (json['change5m'] as num).toDouble(),
        change15m: (json['change15m'] as num).toDouble(),
        change1h: (json['change1h'] as num).toDouble(),
        change24h: (json['change24h'] as num).toDouble(),
        rsi14: (json['rsi14'] as num).toDouble(),
        volume24h: (json['volume24h'] as num).toDouble(),
        avgVolume: (json['avgVolume'] as num).toDouble(),
        support: (json['support'] as num).toDouble(),
        resistance: (json['resistance'] as num).toDouble(),
        atrPct: (json['atrPct'] as num?)?.toDouble() ?? 0,
        recentVolumeRatio: (json['recentVolumeRatio'] as num?)?.toDouble() ?? 1.0,
        at: DateTime.parse(json['at'] as String),
      );
}
