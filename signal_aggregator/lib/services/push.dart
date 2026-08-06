import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'cloud_backend.dart';
import 'notifications.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // The system shows the notification tray entry automatically when the app is
  // backgrounded/terminated. Nothing else to do here.
}

class PushService {
  bool _supported = false;
  bool _ready = false;
  FirebaseMessaging? _messaging;
  CloudBackend? _backend;
  NotificationService? _notifications;
  String? _token;

  bool get isSupported => _supported;
  bool get isReady => _ready;
  String? get token => _token;

  Future<bool> init({
    required CloudBackend? backend,
    required NotificationService notifications,
  }) async {
    _backend = backend;
    _notifications = notifications;
    try {
      await Firebase.initializeApp();
    } catch (_) {
      _supported = false;
      _ready = false;
      return false;
    }

    _supported = true;
    try {
      _messaging = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      FirebaseMessaging.onMessage.listen(_onForeground);
      _messaging!.onTokenRefresh.listen((token) => _register(token));
      await registerCurrentToken();
      _ready = true;
    } catch (_) {
      _ready = false;
    }
    return _ready;
  }

  Future<String?> registerCurrentToken() async {
    final messaging = _messaging;
    if (messaging == null) return null;
    try {
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        _token = token;
        await _register(token);
      }
      return token;
    } catch (_) {
      return null;
    }
  }

  Future<void> _register(String token) async {
    final backend = _backend;
    if (backend == null) return;
    try {
      await backend.registerDevice(token);
    } catch (_) {
      // Best-effort: the cloud backend may be unreachable right now.
    }
  }

  void _onForeground(RemoteMessage message) {
    final data = message.data;
    final symbol = data['symbol'] ?? '';
    final direction = data['direction'] ?? 'buy';
    final title = message.notification?.title ??
        '${direction == 'sell' ? 'SELL' : 'BUY'} $symbol'.trim();
    final body = message.notification?.body ?? 'New trading signal';
    _notifications?.showSignalAlert(
      symbol.isEmpty ? 'signal' : symbol,
      title,
      body,
    );
  }

  Future<void> dispose() async {
    final messaging = _messaging;
    final backend = _backend;
    if (messaging == null) return;
    try {
      final token = _token ?? await messaging.getToken();
      if (token != null && token.isNotEmpty && backend != null) {
        await backend.unregisterDevice(token);
      }
    } catch (_) {
      // Best-effort.
    }
  }
}
