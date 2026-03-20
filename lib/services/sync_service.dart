import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../models/pending_operation.dart';
import '../models/todo.dart';
import 'api_service.dart';
import 'app_state_service.dart';
import 'database_service.dart';

class SyncService {
  static SyncService? _instance;

  static SyncService get instance => _instance ??= SyncService();

  @visibleForTesting
  static void overrideInstance(SyncService service) => _instance = service;

  @visibleForTesting
  static void resetInstance() => _instance = null;

  final DatabaseService _db;
  final ApiService _api;
  final StreamController<void> _syncController =
      StreamController<void>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _pollTimer;
  bool _isSyncing = false;
  static const Duration _pollInterval = Duration(seconds: 30);

  SyncService({DatabaseService? db, ApiService? api})
      : _db = db ?? DatabaseService(),
        _api = api ?? ApiService();

  Stream<void> get onSyncComplete => _syncController.stream;

  bool get isSyncing => _isSyncing;

  void startListening() {
    _startPolling();
    _connectivitySub?.cancel();
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((results) async {
      if (results.contains(ConnectivityResult.none)) {
        AppStateService.instance.setOnline(false);
        return;
      }

      final isOnline = await _api.isOnline();
      if (isOnline && !_isSyncing) {
        await processQueue();
      }
    });
  }

  void stopListening() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<int> getPendingCount() => _db.getPendingOperationsCount();

  Future<void> enqueueOperation(
      String type, Map<String, dynamic> payload) async {
    await _db.savePendingOperation(PendingOperation(
      type: type,
      payload: jsonEncode(payload),
      createdAt: DateTime.now(),
    ));
  }

  Future<void> enqueueTodoCreation(
      String title, String description, String creatorUsername) async {
    await enqueueOperation(PendingOperation.typeCreateTodo, {
      'title': title,
      'description': description,
      'creator_username': creatorUsername,
    });
  }

  Future<void> enqueueMessageSend(String content, {int? tempId}) async {
    await enqueueOperation(PendingOperation.typeSendMessage, {
      'content': content,
      if (tempId != null) 'temp_id': tempId,
    });
  }

  Future<void> enqueueTodoStatusUpdate(int id, bool completed) async {
    await enqueueOperation(PendingOperation.typeUpdateTodoStatus, {
      'id': id,
      'completed': completed,
    });
  }

  Future<void> enqueueTodoDeletion(int id) async {
    await enqueueOperation(PendingOperation.typeDeleteTodo, {
      'id': id,
    });
  }

  Future<void> enqueuePasswordChange(
      String username, String newPassword) async {
    await enqueueOperation(PendingOperation.typeChangePassword, {
      'username': username,
      'new_password': newPassword,
    });
  }

  Future<void> processQueue() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final ops = await _db.getPendingOperations();
      if (ops.isEmpty) {
        _isSyncing = false;
        return;
      }

      bool anySuccess = false;
      for (final op in ops) {
        try {
          await _executeOperation(op);
          await _db.deletePendingOperation(op.id!);
          anySuccess = true;
        } on OfflineException {
          break;
        } catch (_) {
          await _db.deletePendingOperation(op.id!);
          anySuccess = true;
        }
      }

      if (anySuccess) {
        _syncController.add(null);
      }
    } finally {
      _isSyncing = false;
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) async {
      final online = await _checkConnectivity();
      if (online && !_isSyncing) {
        await processQueue();
      }
    });
  }

  Future<bool> _checkConnectivity() async {
    return _api.isOnline();
  }

  Future<void> syncOnAppLaunch() async {
    if (_isSyncing) return;

    final online = await _api.isOnline();
    if (!online) return;

    try {
      await processQueue();

      await _api.getTodos(
        status: 'all',
        sortOrder: 'desc',
        limit: 100,
      );
      await _api.getConversation(page: 1, perPage: 100);
      final unread = await _api.getUnreadCount();
      AppStateService.instance.setUnreadMessages(unread);

      _syncController.add(null);
    } catch (_) {
      // Best effort at startup; regular screen loaders will handle errors.
    }
  }

  Future<void> _executeOperation(PendingOperation op) async {
    final payload = jsonDecode(op.payload) as Map<String, dynamic>;

    switch (op.type) {
      case PendingOperation.typeCreateTodo:
        await _api.createTodo(
          payload['title'] as String,
          payload['description'] as String? ?? '',
        );
      case PendingOperation.typeSendMessage:
        await _api.sendMessage(payload['content'] as String);
        if (payload['temp_id'] != null) {
          await _db.deleteMessageById(payload['temp_id'] as int);
        }
      case PendingOperation.typeUpdateTodoStatus:
        await _api.updateTodoStatus(
          payload['id'] as int,
          payload['completed'] as bool,
        );
      case PendingOperation.typeDeleteTodo:
        await _api.deleteTodo(payload['id'] as int);
      case PendingOperation.typeChangePassword:
        await _api.syncQueuedPasswordChange(payload['new_password'] as String);
    }
  }

  static Todo buildTempTodo({
    required int tempId,
    required String title,
    required String description,
    required int creatorId,
    required String creatorUsername,
  }) {
    final now = DateTime.now();
    return Todo(
      id: tempId,
      title: title,
      description: description,
      creatorId: creatorId,
      creatorUsername: creatorUsername,
      completedAnyel: false,
      completedAlexis: false,
      isCompleted: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  static int tempId() => -(DateTime.now().millisecondsSinceEpoch);
}
