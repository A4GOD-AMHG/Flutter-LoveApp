import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'app_state_service.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  NotificationService.instance.handleNotificationTap(response.payload);
}

class NotificationService with WidgetsBindingObserver {
  NotificationService._();

  static final NotificationService instance = NotificationService._();
  static const int messagesTabIndex = 4;
  static const String _messagesPayload = 'open_messages';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final Map<String, Uint8List> _avatarCache = {};

  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  bool _initialized = false;

  bool get isAppInForeground => _lifecycleState == AppLifecycleState.resumed;

  Future<void> initialize() async {
    if (_initialized) {
      await _syncLaunchIntent();
      return;
    }

    WidgetsBinding.instance.addObserver(this);

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const linux = LinuxInitializationSettings(
      defaultActionName: 'Open notification',
    );

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: android,
        iOS: ios,
        linux: linux,
      ),
      onDidReceiveNotificationResponse: (response) {
        handleNotificationTap(response.payload);
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    final androidImplementation = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestNotificationsPermission();
    await androidImplementation?.createNotificationChannel(
      const AndroidNotificationChannel(
        'messages_channel',
        'Mensajes',
        description: 'Notificaciones de mensajes nuevos',
        importance: Importance.max,
      ),
    );

    final iosImplementation = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await iosImplementation?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    _initialized = true;
    await _syncLaunchIntent();
  }

  Future<void> _syncLaunchIntent() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      handleNotificationTap(details?.notificationResponse?.payload);
    }
  }

  void handleNotificationTap(String? payload) {
    if (payload != _messagesPayload) return;
    AppStateService.instance.requestOpenTab(messagesTabIndex);
  }

  Future<void> handleRemoteMessageTap(RemoteMessage message) async {
    handleNotificationTap(_messagesPayload);
  }

  Future<void> showIncomingMessageNotification({
    required String senderName,
    required String content,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    final avatarBytes = await _loadAvatarBytes(senderName);
    final androidDetails = AndroidNotificationDetails(
      'messages_channel',
      'Mensajes',
      channelDescription: 'Notificaciones de mensajes nuevos',
      importance: Importance.max,
      priority: Priority.high,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.message,
      largeIcon:
          avatarBytes == null ? null : ByteArrayAndroidBitmap(avatarBytes),
      styleInformation: MessagingStyleInformation(
        const Person(name: 'Tu'),
        conversationTitle: senderName,
        messages: [
          Message(
            content,
            DateTime.now(),
            Person(
              name: senderName,
              key: _normalizeSenderKey(senderName),
              icon: await _personIconForSender(senderName),
            ),
          ),
        ],
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      interruptionLevel: InterruptionLevel.active,
      threadIdentifier: 'messages',
    );

    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: senderName,
      body: content,
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: _messagesPayload,
    );
  }

  Future<void> showRemoteMessageNotification(RemoteMessage message) async {
    final senderName = _resolveSenderName(message);
    final content = _resolveMessageBody(message);
    if (senderName == null || content == null) return;

    await showIncomingMessageNotification(
      senderName: senderName,
      content: content,
    );
  }

  String? _resolveSenderName(RemoteMessage message) {
    final data = message.data;
    final candidates = [
      data['sender_name'],
      data['senderName'],
      data['title'],
      data['name'],
      message.notification?.title,
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  String? _resolveMessageBody(RemoteMessage message) {
    final data = message.data;
    final candidates = [
      data['content'],
      data['message'],
      data['body'],
      message.notification?.body,
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  Future<AndroidIcon<Object>?> _personIconForSender(String senderName) async {
    final assetPath = _avatarAssetForSender(senderName);
    if (assetPath == null || kIsWeb) return null;
    return FlutterBitmapAssetAndroidIcon(assetPath);
  }

  Future<Uint8List?> _loadAvatarBytes(String senderName) async {
    final assetPath = _avatarAssetForSender(senderName);
    if (assetPath == null || kIsWeb) return null;

    final cached = _avatarCache[assetPath];
    if (cached != null) return cached;

    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    _avatarCache[assetPath] = bytes;
    return bytes;
  }

  String? _avatarAssetForSender(String senderName) {
    final normalized = _normalizeSenderKey(senderName);
    if (normalized.contains('alexis')) {
      return 'assets/duck.png';
    }
    if (normalized.contains('anyel')) {
      return 'assets/frog.png';
    }
    return null;
  }

  String _normalizeSenderKey(String value) {
    return value.trim().toLowerCase();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
  }
}
