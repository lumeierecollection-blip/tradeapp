import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GithubTriggerService {
  static String get _pat => dotenv.env['GITHUB_PAT'] ?? '';
  static String get _repoOwner => dotenv.env['GITHUB_REPO_OWNER'] ?? '';
  static String get _repoName => dotenv.env['GITHUB_REPO_NAME'] ?? 'tradeapp';

  Future<bool> triggerBacktest({
    required String symbol,
    required String strategy,
    required String timeframe,
  }) async {
    if (_pat.isEmpty || _repoOwner.isEmpty) return false;

    final url = Uri.parse('https://api.github.com/repos/$_repoOwner/$_repoName/dispatches');

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'token $_pat',
          'Accept': 'application/vnd.github+json',
        },
        body: jsonEncode({
          'event_type': 'backtest',
          'client_payload': {
            'symbol': symbol,
            'strategy': strategy,
            'timeframe': timeframe,
          },
        }),
      );

      return response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }
}
