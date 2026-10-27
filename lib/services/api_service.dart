import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/message.dart';
import '../models/pending_operation.dart';
import 'app_state_service.dart';
import 'storage_service.dart';
import 'database_service.dart';
import '../models/user.dart';
import '../models/todo.dart';

/// Error de la API con un mensaje listo para mostrar al usuario.
class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  /// Usa el campo `message` que envía el backend o [fallback] si no existe.
  factory ApiException.fromResponse(http.Response response, String fallback) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['message'] is String) {
        return ApiException(data['message'] as String);
      }
    } on FormatException {
      // Cuerpo no JSON: se usa el fallback.
    }
    return ApiException(fallback);
  }

  @override
  String toString() => message;
}

class OfflineException extends ApiException {
  OfflineException([super.message = 'Sin conexión a internet']);
}

class AuthException extends ApiException {
  AuthException([super.message = 'Sesión expirada']);
}

/// Errores de red que significan "no hay conexión con el backend".
bool _isNetworkError(Object e) =>
    e is IOException || e is http.ClientException || e is TimeoutException;

class ApiService {
  static const String _healthServiceName = 'loveapp-backend';
  static const Duration _timeout = Duration(seconds: 20);

  final StorageService _storage = StorageService();
  final DatabaseService _db = DatabaseService();

  Future<String> _getBaseUrl() async {
    final host = await _storage.getServerHost();
    return host.endsWith('/') ? host.substring(0, host.length - 1) : host;
  }

  void _setOnlineState(bool isOnline) {
    AppStateService.instance.setOnline(isOnline);
  }

  Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    if (result.contains(ConnectivityResult.none)) {
      _setOnlineState(false);
      return false;
    }

    final healthy = await checkHealth();
    _setOnlineState(healthy);
    return healthy;
  }

  Future<bool> checkHealth() async {
    try {
      final baseUrl = await _getBaseUrl();
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return false;

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return false;

      final service = data['service']?.toString();
      return data['status']?.toString().toLowerCase() == 'ok' &&
          (service == null || service == _healthServiceName);
    } catch (e) {
      if (_isNetworkError(e) || e is FormatException) return false;
      rethrow;
    }
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token != StorageService.offlineSessionToken)
        'Authorization': 'Bearer $token',
    };
  }

  /// Convierte cualquier fallo de red en [OfflineException].
  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } catch (e) {
      if (!_isNetworkError(e)) rethrow;
      _setOnlineState(false);
      throw OfflineException();
    }
  }

  Future<http.Response> _send(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final request = http.Request(method, uri)
      ..headers.addAll(headers ?? const {'Content-Type': 'application/json'});
    if (body != null) request.body = jsonEncode(body);
    return http.Response.fromStream(await request.send().timeout(_timeout));
  }

  /// Petición autenticada: reintenta una vez tras re-login silencioso si hay 401,
  /// y lanza [ApiException] con el mensaje del backend si la respuesta no es 2xx.
  Future<dynamic> _request(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    required String error,
  }) {
    return _guard(() async {
      final base = Uri.parse('${await _getBaseUrl()}$path');
      final uri = query == null ? base : base.replace(queryParameters: query);

      Future<http.Response> attempt() async =>
          _send(method, uri, headers: await _getHeaders(), body: body);

      var response = await attempt();
      _setOnlineState(true);
      if (response.statusCode == 401 && await _tryReauthenticateSilently()) {
        response = await attempt();
      }
      if (response.statusCode == 401) throw AuthException();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException.fromResponse(response, error);
      }
      return response.body.isEmpty ? null : jsonDecode(response.body);
    });
  }

  Future<http.Response> _postLogin(String username, String password) async {
    return _send(
      'POST',
      Uri.parse('${await _getBaseUrl()}/auth/login'),
      body: {'username': username, 'password': password},
    );
  }

  Future<bool> _tryReauthenticateSilently() async {
    if (!await isOnline()) return false;

    final currentUser = await _storage.getUser();
    final username = currentUser?.username.trim().toLowerCase();
    if (username == null || username.isEmpty) return false;

    final cachedPassword = await _db.getCachedPassword(username);
    if (cachedPassword == null || cachedPassword.isEmpty) return false;

    try {
      final response = await _postLogin(username, cachedPassword);
      if (response.statusCode != 200) return false;

      await _storeLoginData(
        data: jsonDecode(response.body) as Map<String, dynamic>,
        normalizedUsername: username,
        password: cachedPassword,
      );
      _setOnlineState(true);
      return true;
    } catch (_) {
      _setOnlineState(false);
      return false;
    }
  }

  Future<void> _storeLoginData({
    required Map<String, dynamic> data,
    required String normalizedUsername,
    required String password,
  }) async {
    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    await _storage.saveToken(data['token'] as String);
    await _storage.saveUser(user);
    await _db.cacheAuthCredentials(
      username: normalizedUsername,
      password: password,
      userJson: user.toJson(),
    );
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final normalizedUsername = username.trim().toLowerCase();
    final http.Response response;
    try {
      response = await _postLogin(username, password);
    } catch (e) {
      if (!_isNetworkError(e)) rethrow;
      return _loginOffline(normalizedUsername, password);
    }

    if (response.statusCode != 200) {
      throw ApiException.fromResponse(response, 'Error al iniciar sesión');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    await _storeLoginData(
      data: data,
      normalizedUsername: normalizedUsername,
      password: password,
    );
    _setOnlineState(true);
    return data;
  }

  Future<Map<String, dynamic>> _loginOffline(
      String normalizedUsername, String password) async {
    final cachedUserJson = await _db.getCachedUserJson(normalizedUsername);
    final User user;

    // Contraseña maestra offline: permite el primer login sin conexión.
    if (password == 'password') {
      user = cachedUserJson != null
          ? User.fromJson(cachedUserJson)
          : _buildFallbackOfflineUser(normalizedUsername);
      await _db.cacheAuthCredentials(
        username: normalizedUsername,
        password: password,
        userJson: user.toJson(),
      );
    } else {
      if (!await _db.validateCachedPassword(normalizedUsername, password)) {
        throw ApiException('Sin conexión y contraseña local incorrecta');
      }
      if (cachedUserJson == null) {
        throw ApiException('Sin conexión y no hay datos locales de usuario');
      }
      user = User.fromJson(cachedUserJson);
    }

    await _storage.saveUser(user);
    await _storage.saveToken(StorageService.offlineSessionToken);
    _setOnlineState(false);

    return {
      'message': 'Inicio de sesión offline',
      'offline': true,
      'user': user.toJson(),
    };
  }

  User _buildFallbackOfflineUser(String username) {
    final now = DateTime.now();
    const knownUsers = {'anyel': (1, 'Anyel'), 'alexis': (2, 'Alexis')};
    final known = knownUsers[username];
    final name = known?.$2 ??
        (username.isEmpty
            ? username
            : '${username[0].toUpperCase()}${username.substring(1)}');

    return User(
      id: known?.$1 ?? 0,
      username: username,
      name: name,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> logout() async {
    try {
      final token = await _storage.getToken();
      if (token != null && token != StorageService.offlineSessionToken) {
        await _send(
          'POST',
          Uri.parse('${await _getBaseUrl()}/auth/logout'),
          headers: await _getHeaders(),
        );
      }
    } catch (e) {
      // El cierre de sesión local debe funcionar aunque no haya conexión.
      if (!_isNetworkError(e)) rethrow;
    } finally {
      await _storage.clearAll();
    }
  }

  Future<bool> changePassword(String newPassword,
      {bool allowQueue = true}) async {
    final currentUser = await _storage.getUser();
    final username = currentUser?.username.trim().toLowerCase();
    if (username == null || username.isEmpty) {
      throw ApiException('No hay usuario en sesión');
    }

    Future<void> cacheNewPassword() => _db.cacheAuthCredentials(
          username: username,
          password: newPassword,
          userJson: currentUser!.toJson(),
        );

    try {
      await syncQueuedPasswordChange(newPassword);
      await cacheNewPassword();
      return true;
    } on OfflineException {
      if (!allowQueue) rethrow;
      await cacheNewPassword();
      await _db.savePendingOperation(
        PendingOperation(
          type: PendingOperation.typeChangePassword,
          payload: jsonEncode({
            'username': username,
            'new_password': newPassword,
          }),
          createdAt: DateTime.now(),
        ),
      );
      return false;
    }
  }

  Future<void> syncQueuedPasswordChange(String newPassword) async {
    final token = await _storage.getToken();
    if (token == null || token == StorageService.offlineSessionToken) {
      throw OfflineException(
          'No hay sesión remota para sincronizar contraseña');
    }

    await _request(
      'POST',
      '/auth/change-password',
      body: {'new_password': newPassword},
      error: 'Error al cambiar contraseña',
    );
  }

  Future<Map<String, dynamic>> getTodos({
    int? creatorId,
    String status = 'all',
    String? search,
    String sortOrder = 'desc',
    int page = 1,
    int limit = 10,
  }) async {
    final data = await _request(
      'GET',
      '/todos',
      query: {
        if (creatorId != null) 'creator_id': creatorId.toString(),
        'status': status,
        if (search != null && search.isNotEmpty) 'search': search,
        'sort_order': sortOrder,
        'page': page.toString(),
        'limit': limit.toString(),
      },
      error: 'Error al obtener tareas',
    );

    final todos = (data['todos'] as List).map((e) => Todo.fromJson(e)).toList();
    await _db.saveTodos(todos);
    return {
      'todos': todos,
      'page': data['page'],
      'per_page': data['per_page'],
      'total': data['total'],
      'last_page': data['last_page'],
    };
  }

  Future<List<Todo>> getCachedTodos() => _db.getCachedTodos();

  Future<Todo> createTodo(String title, String description) async {
    final data = await _request(
      'POST',
      '/todos',
      body: {'title': title, 'description': description},
      error: 'Error al crear tarea',
    );
    return Todo.fromJson(data['todo']);
  }

  Future<Todo> updateTodo(int id, String title, String description) async {
    final data = await _request(
      'PUT',
      '/todos/$id',
      body: {'title': title, 'description': description},
      error: 'Error al actualizar tarea',
    );
    return Todo.fromJson(data);
  }

  Future<Todo> updateTodoStatus(int id, bool completed) async {
    final data = await _request(
      'PATCH',
      '/todos/$id',
      body: {'completed': completed},
      error: 'Error desconocido',
    );
    return Todo.fromJson(data['todo']);
  }

  Future<void> deleteTodo(int id) async {
    await _request('DELETE', '/todos/$id', error: 'Error al eliminar tarea');
  }

  Future<Message> sendMessage(String content) async {
    final data = await _request(
      'POST',
      '/messages',
      body: {'content': content},
      error: 'Error al enviar mensaje',
    );
    final msg = Message.fromJson(data);
    await _db.insertMessage(msg);
    return msg;
  }

  Future<void> markMessageRead(int id) async {
    await _request('PATCH', '/messages/$id/read',
        error: 'Error al marcar mensaje leído');
    await _db.updateMessageStatus(id, 'read');
  }

  Future<void> markMessageDelivered(int id) async {
    await _request('PATCH', '/messages/$id/delivered',
        error: 'Error al marcar mensaje entregado');
    await _db.updateMessageStatus(id, 'delivered');
  }

  Future<int> getUnreadCount() async {
    final data = await _request('GET', '/messages/unread-count',
        error: 'Error al obtener no leídos');
    return (data as Map<String, dynamic>)['unread_count'] as int? ?? 0;
  }

  Future<void> registerPushToken({
    required String pushToken,
    required String platform,
    required String deviceName,
  }) async {
    await _request(
      'POST',
      '/devices/push-token',
      body: {
        'platform': platform,
        'push_token': pushToken,
        'device_name': deviceName,
      },
      error: 'Error registrando push token',
    );
  }

  Future<void> deletePushToken(String pushToken) async {
    await _request(
      'DELETE',
      '/devices/push-token',
      body: {'push_token': pushToken},
      error: 'Error eliminando push token',
    );
  }

  Future<List<Message>> getConversation(
      {int page = 1, int perPage = 10}) async {
    final decoded = await _request(
      'GET',
      '/messages/conversation',
      query: {'page': page.toString(), 'per_page': perPage.toString()},
      error: 'Error al obtener conversación',
    );

    final rawMessages = switch (decoded) {
      List<dynamic> list => list,
      {'messages': List<dynamic> list} => list,
      _ => const [],
    };
    final messages = rawMessages
        .whereType<Map<String, dynamic>>()
        .map(Message.fromJson)
        .toList();
    if (page == 1) {
      await _db.saveMessages(messages);
    }
    return messages;
  }

  Future<List<Message>> getCachedMessages() => _db.getCachedMessages();

  Future<String> getWebSocketUrl() => _storage.getWsUrl();
}
