import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/message.dart';
import 'api_service.dart';
import 'app_state_service.dart';
import 'database_service.dart';
import 'notification_service.dart';
import 'storage_service.dart';

class ChatRealtimeService {
  ChatRealtimeService._();

  static final ChatRealtimeService instance = ChatRealtimeService._();

  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();
  final DatabaseService _db = DatabaseService();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  int? _currentUserId;

  bool get isConnected => _subscription != null;

  Future<void> connect() async {
    if (_subscription != null) return;

    final token = await _storage.getToken();
    if (token == null || token == StorageService.offlineSessionToken) return;

    final user = await _storage.getUser();
    _currentUserId = user?.id;

    try {
      final configuredWs = await _api.getWebSocketUrl();
      final uri = Uri.parse(configuredWs);
      final wsUrl = uri.replace(
        queryParameters: {
          ...uri.queryParameters,
          'token': token,
        },
      );

      _channel = WebSocketChannel.connect(wsUrl);
      _subscription = _channel!.stream.listen(
        (data) async {
          try {
            final wsData = jsonDecode(data) as Map<String, dynamic>;
            await _handleWebSocketEvent(wsData);
          } catch (_) {}
        },
        onError: (_) => _cleanupConnection(),
        onDone: _cleanupConnection,
        cancelOnError: false,
      );
    } catch (_) {
      _cleanupConnection();
    }
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  void _cleanupConnection() {
    _subscription = null;
    _channel = null;
  }

  Future<void> _handleWebSocketEvent(Map<String, dynamic> event) async {
    final type = event['type'] as String?;
    final payload = event['payload'];
    if (type == null || payload == null) return;

    final payloadMap = payload is Map<String, dynamic>
        ? payload
        : Map<String, dynamic>.from(payload as Map);

    switch (type) {
      case 'message_sent':
        await _onMessageSentEvent(payloadMap);
      case 'message_updated':
        await _onMessageUpdatedEvent(payloadMap);
      case 'message_deleted':
        await _onMessageDeletedEvent(payloadMap);
      case 'message_delivered':
        await _onMessageStatusEvent(payloadMap, 'delivered');
      case 'message_read':
        await _onMessageStatusEvent(payloadMap, 'read');
    }

    AppStateService.instance.bumpMessagesVersion();
  }

  Future<void> _onMessageSentEvent(Map<String, dynamic> payload) async {
    if (payload['content'] == null ||
        payload['content'].toString().trim().isEmpty) {
      return;
    }

    final message = Message.fromJson(payload);
    await _db.insertMessage(message);

    if (message.senderId == _currentUserId) {
      return;
    }

    await _markAsDelivered(message.id);

    final isMessagesTabOpen = AppStateService.instance.currentTab.value == 4;
    if (isMessagesTabOpen) {
      await _markAsRead(message.id);
      AppStateService.instance.resetUnreadMessages();
      return;
    }

    await _syncUnreadBadge();
    await NotificationService.instance.showIncomingMessageNotification(
      senderName: message.sender.name,
      content: message.content,
    );
  }

  Future<void> _onMessageUpdatedEvent(Map<String, dynamic> payload) async {
    final id = _parseMessageId(payload);
    if (id == null) return;

    final all = await _db.getCachedMessages();
    final idx = all.indexWhere((m) => m.id == id);
    if (idx < 0) return;

    final old = all[idx];
    final updated = Message(
      id: old.id,
      senderId: old.senderId,
      receiverId: old.receiverId,
      sender: old.sender,
      receiver: old.receiver,
      content: payload['content'] as String? ?? old.content,
      status: payload['status'] as String? ?? old.status,
      createdAt: old.createdAt,
      updatedAt: payload['updated_at'] != null
          ? DateTime.parse(payload['updated_at'] as String).toLocal()
          : DateTime.now(),
    );

    await _db.insertMessage(updated);
  }

  Future<void> _onMessageDeletedEvent(Map<String, dynamic> payload) async {
    final id = _parseMessageId(payload);
    if (id == null) return;
    await _db.deleteMessageById(id);
    await _syncUnreadBadge();
  }

  Future<void> _onMessageStatusEvent(
      Map<String, dynamic> payload, String fallbackStatus) async {
    final id = _parseMessageId(payload);
    if (id == null) return;
    final status = payload['status'] as String? ?? fallbackStatus;
    await _db.updateMessageStatus(id, status);
    await _syncUnreadBadge();
  }

  int? _parseMessageId(Map<String, dynamic> payload) {
    final rawId = payload['id'];
    if (rawId is int) return rawId;
    if (rawId is String) return int.tryParse(rawId);
    return null;
  }

  Future<void> _markAsDelivered(int messageId) async {
    try {
      await _api.markMessageDelivered(messageId);
      await _db.updateMessageStatus(messageId, 'delivered');
    } catch (_) {}
  }

  Future<void> _markAsRead(int messageId) async {
    try {
      await _api.markMessageRead(messageId);
      await _db.updateMessageStatus(messageId, 'read');
    } catch (_) {}
  }

  Future<void> _syncUnreadBadge() async {
    if (_currentUserId == null) {
      final user = await _storage.getUser();
      _currentUserId = user?.id;
    }
    if (_currentUserId == null) return;

    final unread = await _db.getUnreadMessagesCount(_currentUserId!);
    AppStateService.instance.setUnreadMessages(unread);
  }
}
