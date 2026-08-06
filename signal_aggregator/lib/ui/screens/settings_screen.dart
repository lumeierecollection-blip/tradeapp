import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const List<String> _allCoins = [
    'BTC', 'ETH', 'SOL', 'BNB', 'XRP', 'ADA', 'DOGE', 'AVAX', 'LINK',
    'DOT', 'MATIC', 'LTC', 'UNI', 'ARB', 'OP', 'SHIB', 'TRX', 'NEAR', 'APT', 'FIL',
  ];

  final _channelController = TextEditingController();
  final _balanceController = TextEditingController();
  final _cloudUrlController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appState = context.watch<AppState>();
    if (_channelController.text.isEmpty && appState.telegramChannels.isNotEmpty) {
      _channelController.text = appState.telegramChannels.join(', ');
    }
    if (_cloudUrlController.text.isEmpty && appState.cloudUrl.isNotEmpty) {
      _cloudUrlController.text = appState.cloudUrl;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final trader = appState.paperTrader;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionLabel('Watchlist'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allCoins.map((coin) {
                  final selected = appState.watchlist.contains(coin);
                  return FilterChip(
                    label: Text(coin),
                    selected: selected,
                    onSelected: (sel) {
                      final list = List<String>.from(appState.watchlist);
                      if (sel) {
                        list.add(coin);
                      } else {
                        list.remove(coin);
                      }
                      appState.setWatchlist(list);
                    },
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionLabel('Signal sources'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _SourceTile(
                  title: 'Reddit',
                  subtitle: 'Free official feed. Posts from crypto subreddits.',
                  value: appState.sourcesEnabled['reddit'] ?? true,
                  onChanged: (v) => appState.setSourceEnabled('reddit', v),
                ),
                const Divider(height: 1, color: Color(0xFF222B3A)),
                _SourceTile(
                  title: 'Crypto news',
                  subtitle: 'Free news headlines (CryptoCompare).',
                  value: appState.sourcesEnabled['news'] ?? true,
                  onChanged: (v) => appState.setSourceEnabled('news', v),
                ),
                const Divider(height: 1, color: Color(0xFF222B3A)),
                _SourceTile(
                  title: 'CoinDesk news',
                  subtitle: 'Second free news feed (RSS) for broader altcoin coverage.',
                  value: appState.sourcesEnabled['rss'] ?? true,
                  onChanged: (v) => appState.setSourceEnabled('rss', v),
                ),
                const Divider(height: 1, color: Color(0xFF222B3A)),
                _SourceTile(
                  title: 'Market pulse',
                  subtitle: 'Technical setups from all markets — signals even for coins with no social chatter.',
                  value: appState.sourcesEnabled['pulse'] ?? true,
                  onChanged: (v) => appState.setSourceEnabled('pulse', v),
                ),
                const Divider(height: 1, color: Color(0xFF222B3A)),
                _SourceTile(
                  title: 'Telegram channels',
                  subtitle: 'Public channels only. No private groups or encrypted chats.',
                  value: appState.sourcesEnabled['telegram'] ?? false,
                  onChanged: (v) => appState.setSourceEnabled('telegram', v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionLabel('Cloud feed'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Use cloud feed'),
                  subtitle: const Text(
                    'Runs the scanning 24/7 in the cloud, so you get fresh signals '
                    'without your PC on or the app being open.',
                  ),
                  value: appState.cloudEnabled,
                  onChanged: appState.setCloudEnabled,
                ),
                const Divider(height: 1, color: Color(0xFF222B3A)),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Backend URL (from your deployed cloud backend):',
                        style: TextStyle(fontSize: 13, color: Colors.white54),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _cloudUrlController,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          hintText: 'https://your-backend-url',
                          labelText: 'Cloud URL',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            appState.setCloudUrl(_cloudUrlController.text);
                            appState.syncPushRegistration();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Cloud URL saved')),
                            );
                          },
                          child: const Text('Save URL'),
                        ),                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionLabel('Telegram channels'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Public channel usernames, comma separated. Only channels that show a public preview at t.me/NAME work.',
                    style: TextStyle(fontSize: 13, color: Colors.white54, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _channelController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. CryptoSignals, btc_daily',
                      labelText: 'Channels',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        final list = _channelController.text
                            .split(RegExp(r'[,;\s]+'))
                            .where((s) => s.isNotEmpty)
                            .map((s) => s.replaceFirst('@', ''))
                            .toList();
                        appState.setTelegramChannels(list);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Saved ${list.length} channel(s)')),
                        );
                      },
                      child: const Text('Save channels'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionLabel('Alerts'),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              title: const Text('Notify me on strong signals'),
              subtitle: const Text('Alerts for signals with 70%+ rightness.'),
              value: appState.notificationsEnabled,
              onChanged: appState.setNotificationsEnabled,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.notifications_active, size: 18, color: Colors.white70),
                      const SizedBox(width: 8),
                      Text(
                        'Cloud push alerts',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _pushStatusText(appState),
                    style: const TextStyle(fontSize: 12.5, color: Colors.white54, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionLabel('Paper trading'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current balance: \$${trader.balance.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Reset paper balance to start over. This does not touch your real money.',
                    style: TextStyle(fontSize: 13, color: Colors.white54),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _balanceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'New balance',
                            prefixText: '\$ ',
                            hintText: '500',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: () {
                          final v = double.tryParse(_balanceController.text.replaceAll(',', '.'));
                          if (v == null || v <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Enter a valid amount')),
                            );
                            return;
                          }
                          trader.resetBalance(v);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Paper balance reset to \$${v.toStringAsFixed(2)}')),
                          );
                        },
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionLabel('Where to trade'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your \$5 plan, in order:',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  _bullet(
                    text:
                        '1. Learn here with paper money until accuracy looks good (aim for 55%+ win rate over 20+ trades).',
                  ),
                  _bullet(
                    text:
                        '2. Open a Bybit account and use its free demo trading to practice the same moves on a real exchange.',
                  ),
                  _bullet(
                    text:
                        '3. Deposit real USDT via crypto transfer (free, no minimum). Trade the coins this app rates highest.',
                  ),
                  _bullet(
                    text:
                        '4. Withdraw USDT on the TRC-20 network for same-day withdrawals. Keep fees low: MEXC has the lowest (0% maker).',
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Warning: at \$5 size, a single trade fee (~0.1%) is small, but losses are real. Never trade money you cannot afford to lose.',
                    style: TextStyle(fontSize: 13, color: Color(0xFFF0C9C9), height: 1.4),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionLabel('About'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'signal_aggregator · personal Android app',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This app aggregates public posts and news, then checks them against live market data. It is an educational tool, not financial advice. No prediction is guaranteed.',
                    style: TextStyle(fontSize: 13, color: Colors.white54, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => Clipboard.setData(
                      const ClipboardData(text: 'signal_aggregator'),
                    ),
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy app name'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _pushStatusText(AppState appState) {
    if (!appState.pushSupported) {
      return 'Not set up yet. Once you add the Firebase config (google-services.json) '
          'and save a Cloud URL, the app tells the cloud to ping your phone the moment '
          'it finds a 70%+ signal. The app still works fine without it.';
    }
    if (!appState.pushReady) {
      return 'Initializing…';
    }
    if (!appState.cloudEnabled || appState.cloudUrl.trim().isEmpty) {
      return 'Ready, but no Cloud URL saved yet. Save one above and this phone will '
          'receive a push the moment the cloud finds a 70%+ signal.';
    }
    return 'Active. When the cloud scan finds a new 70%+ signal, this phone gets a '
        'push notification — even with the app closed and your PC off.';
  }

  Widget _bullet({required String text}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Icon(Icons.circle, size: 5, color: AppTheme.accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: const TextStyle(fontSize: 13.5, color: Color(0xFFC3CAD6), height: 1.5)),
            ),
          ],
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w700, color: Colors.white54),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SourceTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12.5, color: Colors.white54)),
      value: value,
      onChanged: onChanged,
    );
  }
}
