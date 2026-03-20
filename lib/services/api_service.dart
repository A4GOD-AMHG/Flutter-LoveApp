import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/message.dart';
import '../models/pending_operation.dart';
import 'storage_service.dart';
import 'database_service.dart';
import '../models/user.dart';
import '../models/todo.dart';
import 'dart:convert';
import 'dart:io';

class OfflineException implements Exception {
  final String message;
  OfflineException([this.message = 'Sin conexión a internet']);
}

class ApiService {
  final StorageService _storage = StorageService();
  final DatabaseService _db = DatabaseService();

  Future<String> _getBaseUrl() async {
    final host = await _storage.getServerHost();
    return host.endsWith('/') ? host.substring(0, host.length - 1) : host;
  }

  Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token != StorageService.offlineSessionToken)
        'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final baseUrl = await _getBaseUrl();
    final normalizedUsername = username.trim().toLowerCase();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final user = User.fromJson(data['user'] as Map<String, dynamic>);
        await _storage.saveToken(data['token'] as String);
        await _storage.saveUser(user);
        await _db.cacheAuthCredentials(
          username: normalizedUsername,
          password: password,
          userJson: user.toJson(),
        );
        return data;
      } else {
        throw Exception('Login fallido: ${response.body}');
      }
    } on SocketException {
      return _loginOffline(normalizedUsername, password);
    } on HttpException {
      return _loginOffline(normalizedUsername, password);
    } on HandshakeException {
      return _loginOffline(normalizedUsername, password);
    } on http.ClientException {
      return _loginOffline(normalizedUsername, password);
    }
  }

  Future<Map<String, dynamic>> _loginOffline(
      String username, String password) async {
    final valid = await _db.validateCachedPassword(username, password);
    if (!valid) {
      throw Exception('Sin conexión y contraseña local incorrecta');
    }

    final userJson = await _db.getCachedUserJson(username);
    if (userJson == null) {
      throw Exception('Sin conexión y no hay datos locales de usuario');
    }

    final user = User.fromJson(userJson);
    await _storage.saveUser(user);
    await _storage.saveToken(StorageService.offlineSessionToken);

    return {
      'message': 'Inicio de sesión offline',
      'offline': true,
      'user': user.toJson(),
    };
  }

  Future<void> logout() async {
    try {
      final token = await _storage.getToken();
      if (token != null && token != StorageService.offlineSessionToken) {
        final baseUrl = await _getBaseUrl();
        final headers = await _getHeaders();
        await http.post(
          Uri.parse('$baseUrl/auth/logout'),
          headers: headers,
        );
      }
    } on SocketException {
      // Allow local logout while offline.
    } on HttpException {
      // Allow local logout while offline.
    } on HandshakeException {
      // Allow local logout while offline.
    } on http.ClientException {
      // Allow local logout while offline.
    } finally {
      await _storage.clearAll();
    }
  }

  Future<bool> changePassword(String newPassword,
      {bool allowQueue = true}) async {
    final currentUser = await _storage.getUser();
    final username = currentUser?.username.trim().toLowerCase();
    if (username == null || username.isEmpty) {
      throw Exception('No hay usuario en sesión');
    }

    try {
      await syncQueuedPasswordChange(newPassword);
      await _db.updateCachedPassword(username, newPassword);
      return true;
    } on OfflineException {
      if (!allowQueue) rethrow;
      await _db.updateCachedPassword(username, newPassword);
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

    final baseUrl = await _getBaseUrl();
    final headers = await _getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/change-password'),
        headers: headers,
        body: jsonEncode({'new_password': newPassword}),
      );

      if (response.statusCode != 200) {
        throw Exception('Error al cambiar contraseña: ${response.body}');
      }
    } on SocketException {
      throw OfflineException();
    } on HttpException {
      throw OfflineException();
    } on HandshakeException {
      throw OfflineException();
    } on http.ClientException {
      throw OfflineException();
    }
  }

  Future<Map<String, dynamic>> getTodos({
    int? creatorId,
    String status = 'all',
    String? search,
    String sortOrder = 'desc',
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final baseUrl = await _getBaseUrl();
      final headers = await _getHeaders();
      final queryParams = {
        if (creatorId != null) 'creator_id': creatorId.toString(),
        'status': status,
        if (search != null && search.isNotEmpty) 'search': search,
        'sort_order': sortOrder,
        'page': page.toString(),
        'limit': limit.toString(),
      };

      final uri =
          Uri.parse('$baseUrl/todos').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final todos =
            (data['todos'] as List).map((e) => Todo.fromJson(e)).toList();
        await _db.saveTodos(todos);
        return {
          'todos': todos,
          'page': data['page'],
          'per_page': data['per_page'],
          'total': data['total'],
          'last_page': data['last_page'],
        };
      } else {
        throw Exception('Error al obtener tareas: ${response.body}');
      }
    } on SocketException {
      throw OfflineException();
    } on HttpException {
      throw OfflineException();
    }
  }

  Future<List<Todo>> getCachedTodos() => _db.getCachedTodos();

  Future<Todo> createTodo(String title, String description) async {
    final baseUrl = await _getBaseUrl();
    final headers = await _getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/todos'),
        headers: headers,
        body: jsonEncode({
          'title': title,
          'description': description,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return Todo.fromJson(data['todo']);
      } else {
        throw Exception('Error al crear tarea: ${response.body}');
      }
    } on SocketException {
      throw OfflineException();
    }
  }

  Future<Todo> updateTodo(int id, String title, String description) async {
    final baseUrl = await _getBaseUrl();
    final headers = await _getHeaders();
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/todos/$id'),
        headers: headers,
        body: jsonEncode({
          'title': title,
          'description': description,
        }),
      );

      if (response.statusCode == 200) {
        return Todo.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Error al actualizar tarea: ${response.body}');
      }
    } on SocketException {
      throw OfflineException();
    }
  }

  Future<Todo> updateTodoStatus(int id, bool completed) async {
    final baseUrl = await _getBaseUrl();
    final headers = await _getHeaders();
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/todos/$id'),
        headers: headers,
        body: jsonEncode({'completed': completed}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Todo.fromJson(data['todo']);
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['message'] ?? 'Error desconocido';
        throw Exception(errorMessage);
      }
    } on SocketException {
      throw OfflineException();
    }
  }

  Future<void> deleteTodo(int id) async {
    final baseUrl = await _getBaseUrl();
    final headers = await _getHeaders();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/todos/$id'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        throw Exception('Error al eliminar tarea: ${response.body}');
      }
    } on SocketException {
      throw OfflineException();
    }
  }

  Future<Message> sendMessage(String content) async {
    final baseUrl = await _getBaseUrl();
    final headers = await _getHeaders();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/messages'),
        headers: headers,
        body: jsonEncode({'content': content}),
      );

      if (response.statusCode == 201) {
        final msg = Message.fromJson(jsonDecode(response.body));
        await _db.insertMessage(msg);
        return msg;
      } else {
        throw Exception('Error al enviar mensaje: ${response.body}');
      }
    } on SocketException {
      throw OfflineException();
    }
  }

  Future<void> markMessageRead(int id) async {
    final baseUrl = await _getBaseUrl();
    final headers = await _getHeaders();
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/messages/$id/read'),
        headers: headers,
      );
      if (response.statusCode != 200) {
        throw Exception('Error al marcar mensaje leído: ${response.body}');
      }
      await _db.updateMessageStatus(id, 'read');
    } on SocketException {
      throw OfflineException();
    } on HttpException {
      throw OfflineException();
    } on HandshakeException {
      throw OfflineException();
    } on http.ClientException {
      throw OfflineException();
    }
  }

  Future<void> markMessageDelivered(int id) async {
    final baseUrl = await _getBaseUrl();
    final headers = await _getHeaders();
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/messages/$id/delivered'),
        headers: headers,
      );
      if (response.statusCode != 200) {
        throw Exception('Error al marcar mensaje entregado: ${response.body}');
      }
      await _db.updateMessageStatus(id, 'delivered');
    } on SocketException {
      throw OfflineException();
    } on HttpException {
      throw OfflineException();
    } on HandshakeException {
      throw OfflineException();
    } on http.ClientException {
      throw OfflineException();
    }
  }

  Future<List<Message>> getConversation(
      {int page = 1, int perPage = 10}) async {
    try {
      final baseUrl = await _getBaseUrl();
      final headers = await _getHeaders();
      final uri = Uri.parse('$baseUrl/messages/conversation').replace(
        queryParameters: {
          'page': page.toString(),
          'per_page': perPage.toString(),
        },
      );

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final messages = data.map((e) => Message.fromJson(e)).toList();
        if (page == 1) {
          await _db.saveMessages(messages);
        }
        return messages;
      } else {
        throw Exception('Error al obtener conversación: ${response.body}');
      }
    } on SocketException {
      throw OfflineException();
    } on HttpException {
      throw OfflineException();
    }
  }

  Future<List<Message>> getCachedMessages() => _db.getCachedMessages();

  Future<String> getWebSocketUrl() => _storage.getWsUrl();
}
