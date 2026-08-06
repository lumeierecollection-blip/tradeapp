import 'market_service.dart';

class Symbols {
  static const Map<String, String> _aliases = {
    'bitcoin': 'BTC',
    'btc': 'BTC',
    'ethereum': 'ETH',
    'ether': 'ETH',
    'eth': 'ETH',
    'solana': 'SOL',
    'sol': 'SOL',
    'bnb': 'BNB',
    'binance coin': 'BNB',
    'xrp': 'XRP',
    'ripple': 'XRP',
    'cardano': 'ADA',
    'ada': 'ADA',
    'dogecoin': 'DOGE',
    'doge': 'DOGE',
    'avalanche': 'AVAX',
    'avax': 'AVAX',
    'chainlink': 'LINK',
    'link': 'LINK',
    'polkadot': 'DOT',
    'dot': 'DOT',
    'polygon': 'MATIC',
    'matic': 'MATIC',
    'litecoin': 'LTC',
    'ltc': 'LTC',
    'uniswap': 'UNI',
    'uni': 'UNI',
    'arbitrum': 'ARB',
    'arb': 'ARB',
    'optimism': 'OP',
    'shiba': 'SHIB',
    'shib': 'SHIB',
    'shiba inu': 'SHIB',
    'tron': 'TRX',
    'trx': 'TRX',
    'near': 'NEAR',
    'near protocol': 'NEAR',
    'aptos': 'APT',
    'apt': 'APT',
    'filecoin': 'FIL',
    'fil': 'FIL',
  };

  static List<String> extract(String text) {
    final found = <String, bool>{};
    final lower = text.toLowerCase();
    _aliases.forEach((key, symbol) {
      if (MarketService.toPair(symbol) == null) return;
      if (_containsWord(lower, key)) found[symbol] = true;
    });
    final regex = RegExp(r'#?[$]?\b([A-Za-z]{2,8})\b(USDT|USD)?', caseSensitive: false);
    for (final m in regex.allMatches(text)) {
      final candidate = m.group(1)!.toUpperCase();
      if (MarketService.toPair(candidate) != null) found[candidate] = true;
    }
    return found.keys.toList();
  }

  static bool _containsWord(String lower, String word) {
    var index = lower.indexOf(word);
    while (index != -1) {
      final beforeOk = index == 0 || !_isAlphaNumeric(lower[index - 1]);
      final afterIndex = index + word.length;
      final afterOk = afterIndex >= lower.length || !_isAlphaNumeric(lower[afterIndex]);
      if (beforeOk && afterOk) return true;
      final next = lower.indexOf(word, index + 1);
      if (next == index) break;
      index = next;
    }
    return false;
  }

  static bool _isAlphaNumeric(String c) {
    final code = c.codeUnitAt(0);
    return (code >= 48 && code <= 57) || (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
  }
}
