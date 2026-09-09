/// One OHLCV candle. Chronological lists of these are the only market input the
/// backtester takes — no live calls, no look-ahead beyond the current index.
class Bar {
  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  const Bar({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  /// A Binance kline row: [openTime, open, high, low, close, volume, ...].
  factory Bar.fromKline(List<dynamic> row) => Bar(
        time: DateTime.fromMillisecondsSinceEpoch((row[0] as num).toInt()),
        open: double.parse(row[1].toString()),
        high: double.parse(row[2].toString()),
        low: double.parse(row[3].toString()),
        close: double.parse(row[4].toString()),
        volume: double.parse(row[5].toString()),
      );
}
