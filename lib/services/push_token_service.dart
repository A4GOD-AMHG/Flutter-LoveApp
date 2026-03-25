import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service.dart';
import 'notification_service.dart';
import 'storage_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {}

  await NotificationService.instance.initialize();

  if (message.notification == null) {
    await NotificationService.instance.showRemoteMessageNotification(message);
  }
}

class PushTokenService {
  PushTokenService._();

  static final PushTokenService instance = PushTokenService._();

  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
    } catch (_) {
      // Firebase not configured for this platform/environment.
      return;
    }

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    await messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((message) async {
      await NotificationService.instance.showRemoteMessageNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      await NotificationService.instance.handleRemoteMessageTap(message);
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      await _storage.savePushToken(newToken);
      await syncTokenWithBackend();
    });

    final token = await messaging.getToken();
    if (token != null && token.isNotEmpty) {
      await _storage.savePushToken(token);
    }

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      await NotificationService.instance.handleRemoteMessageTap(initialMessage);
    }

    _initialized = true;
  }

  Future<void> syncTokenWithBackend() async {
    final authToken = await _storage.getToken();
    if (authToken == null || authToken == StorageService.offlineSessionToken) {
      return;
    }

    String? pushToken = await _storage.getPushToken();
    if ((pushToken == null || pushToken.isEmpty) && !kIsWeb) {
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp();
        }
        pushToken = await FirebaseMessaging.instance.getToken();
        if (pushToken != null && pushToken.isNotEmpty) {
          await _storage.savePushToken(pushToken);
        }
      } catch (_) {
        return;
      }
    }

    if (pushToken == null || pushToken.isEmpty) return;

    try {
      await _api.registerPushToken(
        pushToken: pushToken,
        platform: _platformName(),
        deviceName: _deviceName(),
      );
    } catch (_) {}
  }

  Future<void> unregisterTokenFromBackend() async {
    final authToken = await _storage.getToken();
    if (authToken == null || authToken == StorageService.offlineSessionToken) {
      await _storage.clearPushToken();
      return;
    }

    String? pushToken = await _storage.getPushToken();
    if ((pushToken == null || pushToken.isEmpty) && !kIsWeb) {
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp();
        }
        pushToken = await FirebaseMessaging.instance.getToken();
      } catch (_) {}
    }

    if (pushToken != null && pushToken.isNotEmpty) {
      try {
        await _api.deletePushToken(pushToken);
      } catch (_) {}
    }

    await _storage.clearPushToken();
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  String _deviceName() {
    if (kIsWeb) return 'web';
    return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
  }
}
