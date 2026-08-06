import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _tzReady = false;

  Future<void> init() async {
    if (!_tzReady) {
      tzdata.initializeTimeZones();
      _tzReady = true;
    }
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings);
  }

  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    await android.requestNotificationsPermission();
    return await android.requestExactAlarmsPermission() ?? false;
  }

  /// Reminders for an open position: 5 min before the close time, 2 min before,
  /// and exactly at the close time. Scheduling is skipped for moments already
  /// in the past.
  Future<void> scheduleTradeReminders(
      String tradeId, String symbol, DateTime sellAt) async {
    final base = tradeId.hashCode & 0x3FFFFFFF;
    final entries = <(int, DateTime, String, String)>[
      (base, sellAt.subtract(const Duration(minutes: 5)),
          'Close $symbol in 5 minutes',
          '$symbol reaches your close time at ${_clock(sellAt)}.'),
      (base + 1, sellAt.subtract(const Duration(minutes: 2)),
          'Close $symbol in 2 minutes',
          'Wrap up the position — target window ends at ${_clock(sellAt)}.'),
      (base + 2, sellAt, 'Time to close $symbol',
          'Your $symbol close time is now. Review and close the position.'),
    ];
    for (final (id, at, title, body) in entries) {
      if (!at.isAfter(DateTime.now())) continue;
      await _scheduleAt(id, at, title, body);
    }
  }

  Future<void> cancelTradeReminders(String tradeId) async {
    final base = tradeId.hashCode & 0x3FFFFFFF;
    await _plugin.cancel(base);
    await _plugin.cancel(base + 1);
    await _plugin.cancel(base + 2);
  }

  Future<void> _scheduleAt(int id, DateTime when, String title, String body) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'position_reminders',
        'Position reminders',
        channelDescription: 'Reminders to close open positions at the signal time',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    // The instant is what matters on Android (epoch millis for AlarmManager),
    // so schedule in UTC to stay correct regardless of the device timezone.
    final whenUtc = tz.TZDateTime.from(when.toUtc(), tz.UTC);
    try {
      await _plugin.zonedSchedule(id, title, body, whenUtc, details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime);
    } catch (_) {
      await _plugin.zonedSchedule(id, title, body, whenUtc, details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime);
    }
  }

  Future<void> showSignalAlert(String symbol, String title, String body) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'trade_signals',
        'Trade signals',
        channelDescription: 'High-probability trading signal alerts',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.show(
      symbol.hashCode,
      title,
      body,
      details,
    );
  }

  Future<void> showInfo(String title, String body) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'app_updates',
        'App updates',
        channelDescription: 'App status notifications',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

  static String _clock(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
