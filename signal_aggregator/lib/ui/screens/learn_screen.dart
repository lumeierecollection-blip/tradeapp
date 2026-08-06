import 'package:flutter/material.dart';

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  static const List<({String title, String body})> _lessons = [
    (
      title: 'What is a "signal"?',
      body: 'A signal is a piece of information that hints a coin might go up or down. '
          'It can come from a Reddit post, a news headline, or a Telegram channel. '
          'Most signals are just opinions — that is why this app checks them against '
          'real market data before showing them to you.'
    ),
    (
      title: 'What "rightness probability" means',
      body: 'It is NOT a guarantee. It is a score out of 100 that blends five checks: '
          'price momentum (is price moving the way the post says?), volume (are real '
          'people trading this?), RSI (is it overbought/oversold?), entry zone (is it '
          'near support or resistance?), and message clarity. A 70% score means the '
          'evidence lines up well — not that it always wins.'
    ),
    (
      title: 'Momentum',
      body: 'Momentum is how fast and in which direction price moved recently. '
          'If a post says "buy" and price is already rising, the market agrees — '
          'that raises the score. If a post says "buy" but price is crashing, the '
          'post is probably wrong or late.'
    ),
    (
      title: 'Volume',
      body: 'Volume is how many coins changed hands. High volume behind a move means '
          'many people are acting on it — harder to fake. Low volume means the move '
          'is fragile and can reverse quickly.'
    ),
    (
      title: 'RSI (Relative Strength Index)',
      body: 'RSI is a number from 0 to 100 that measures if price moved too far, too fast. '
          'Above 70 = "overbought" (price may be overpriced and due to fall). Below 30 = '
          '"oversold" (may be a bargain, due to bounce). The app likes buying when RSI is '
          'comfortable, not when it is already stretched.'
    ),
    (
      title: 'Support and resistance',
      body: 'Support is a price floor where buyers historically step in; resistance is a '
          'ceiling where sellers appear. Buying near support (a cheap area) gives a better '
          'risk/reward than buying near resistance (an expensive area).'
    ),
    (
      title: 'Stop loss and take profit',
      body: 'A stop loss is the price where you admit you are wrong and exit — it limits '
          'your loss. A take profit is the price where you lock in a gain. The app sets '
          'these so your potential gain is about 1.5x your potential loss. That means you '
          'can be wrong 4 out of 10 times and still come out ahead.'
    ),
    (
      title: 'Paper trading first',
      body: 'You are trading with fake money until the app\'s signals prove accurate over '
          'several weeks. This is the safe way to learn. Only when your win rate and '
          'high-confidence accuracy look good should you switch to your real \$5.'
    ),
    (
      title: 'Fees and where to trade',
      body: 'Crypto exchanges charge a small fee per trade (about 0.1%). At \$5 size, fees '
          'eat a big share of small wins — that is normal at the start. Recommended: Bybit '
          'for its built-in demo trading while you learn, then MEXC for the lowest fees. '
          'Deposit via crypto transfer (free) and withdraw USDT on TRC-20 for same-day '
          'withdrawals.'
    ),
    (
      title: 'Scams in signal groups',
      body: 'Most Telegram and X "signal" channels are either scams or paid marketing. '
          'Red flags: "guaranteed profit", "insider info", "send me coins to double it", '
          'or pumping a tiny unknown coin (pump-and-dump). Treat every signal as an opinion '
          'and always check the market — which is exactly what this app does for you.'
    ),
    (
      title: 'Why the app checks every 5 minutes',
      body: 'Signals go stale fast in crypto. The app rescans sources and rechecks the market '
          'every 5 minutes while it is open, and best-effort in the background. Android may '
          'pause background scans to save battery, so keep the app open or tap refresh when '
          'you want fresh results.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Learn')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Everything in simple language. Read a few before your first trade.',
              style: TextStyle(fontSize: 14, color: Colors.white54),
            ),
          ),
          for (final lesson in _lessons)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  shape: const Border(),
                  title: Text(
                    lesson.title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.body,
                      style: const TextStyle(fontSize: 14, color: Color(0xFFC3CAD6), height: 1.55),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
