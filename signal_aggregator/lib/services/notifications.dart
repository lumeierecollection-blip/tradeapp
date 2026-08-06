import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings);
  }

  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    return await android.requestNotificationsPermission() ?? false;
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
}
