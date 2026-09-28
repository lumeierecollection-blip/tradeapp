import 'package:flutter/material.dart';

import '../theme.dart';
import 'review_screen.dart';
import 'settings_screen.dart';

/// Secondary screens that don't warrant their own bottom tab.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _tile(context, Icons.fact_check_outlined, 'Review',
              'Journal, calibration and per-symbol results', const ReviewScreen()),
          _tile(context, Icons.settings_outlined, 'Settings',
              'Watchlist, sources, notifications, cloud', const SettingsScreen()),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, String subtitle, Widget screen) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.accent),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)),
    );
  }
}
