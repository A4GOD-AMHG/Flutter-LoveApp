import 'package:http/http.dart' as http;
import '../models/message.dart';
import 'storage_service.dart';
import '../models/user.dart';
import '../models/todo.dart';
import 'dart:convert';

class ApiService {
  static const String baseUrl = 'http://localhost:8080';
  final StorageService _storage = StorageService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await _storage.saveToken(data['token']);
      await _storage.saveUser(User.fromJson(data['user']));
      return data;
    } else {
      throw Exception('Login fallido: ${response.body}');
    }
  }

  Future<void> logout() async {
    try {
      final headers = await _getHeaders();
      await http.post(
        Uri.parse('$baseUrl/auth/logout'),
        headers: headers,
      );
    } finally {
      await _storage.clearAll();
    }
  }

  Future<void> changePassword(String newPassword) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/auth/change-password'),
      headers: headers,
      body: jsonEncode({'new_password': newPassword}),
    );

    if (response.statusCode != 200) {
      throw Exception('Error al cambiar contraseña: ${response.body}');
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
      return {
        'todos': (data['todos'] as List).map((e) => Todo.fromJson(e)).toList(),
        'page': data['page'],
        'per_page': data['per_page'],
        'total': data['total'],
        'last_page': data['last_page'],
      };
    } else {
      throw Exception('Error al obtener tareas: ${response.body}');
    }
  }

  Future<Todo> createTodo(String title, String description) async {
    final headers = await _getHeaders();
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
  }

  Future<Todo> updateTodo(int id, String title, String description) async {
    final headers = await _getHeaders();
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
  }

  Future<Todo> updateTodoStatus(int id, bool completed) async {
    final headers = await _getHeaders();
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
  }

  Future<void> deleteTodo(int id) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/todos/$id'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Error al eliminar tarea: ${response.body}');
    }
  }

  Future<Message> sendMessage(String content) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/messages'),
      headers: headers,
      body: jsonEncode({'content': content}),
    );

    if (response.statusCode == 201) {
      return Message.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Error al enviar mensaje: ${response.body}');
    }
  }

  Future<List<Message>> getConversation(
      {int page = 1, int perPage = 20}) async {
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
      return data.map((e) => Message.fromJson(e)).toList();
    } else {
      throw Exception('Error al obtener conversación: ${response.body}');
    }
  }

  String getWebSocketUrl() {
    return 'ws://localhost:8080/ws';
  }
}
