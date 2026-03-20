import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService with WidgetsBindingObserver {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  bool _initialized = false;

  bool get isAppInForeground => _lifecycleState == AppLifecycleState.resumed;

  Future<void> initialize() async {
    if (_initialized) return;

    WidgetsBinding.instance.addObserver(this);

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();

    await _plugin.initialize(
      const InitializationSettings(
        android: android,
        iOS: ios,
      ),
    );

    final androidImplementation = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestNotificationsPermission();

    final iosImplementation = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await iosImplementation?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    _initialized = true;
  }

  Future<void> showIncomingMessageNotification({
    required String senderName,
    required String content,
  }) async {
    if (!_initialized) return;

    const androidDetails = AndroidNotificationDetails(
      'messages_channel',
      'Mensajes',
      channelDescription: 'Notificaciones de mensajes nuevos',
      importance: Importance.max,
      priority: Priority.high,
      visibility: NotificationVisibility.public,
    );

    const iosDetails = DarwinNotificationDetails();

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      senderName,
      content,
      const NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
  }
}
