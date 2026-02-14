import '../services/storage_service.dart';
import '../utils/theme_controller.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/header.dart';
import '../models/todo.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final ApiService _apiService = ApiService();
  final StorageService _storage = StorageService();
  List<Todo> _todos = [];
  bool _isLoading = false;
  String _filter = 'all';
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadTodos();
  }

  Future<void> _loadCurrentUser() async {
    final user = await _storage.getUser();
    setState(() {
      _currentUserId = user?.id;
    });
  }

  Future<void> _loadTodos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _apiService.getTodos(
        status: _filter,
        sortOrder: 'desc',
        limit: 100,
      );
      setState(() {
        _todos = result['todos'] as List<Todo>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar tareas: $e')),
        );
      }
    }
  }

  Future<void> _createTodo() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final themeController = ThemeProvider.of(context);
        final isDark = themeController.isDark;
        final textColor = isDark ? Colors.white : Colors.black87;
        final cardColor = isDark ? const Color(0xFF2d2640) : Colors.white;

        return AlertDialog(
          backgroundColor: cardColor,
          title: Text('Nueva Tarea', style: TextStyle(color: textColor)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Título',
                  labelStyle:
                      TextStyle(color: textColor.withValues(alpha: 0.7)),
                  enabledBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: textColor.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: textColor),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                maxLines: 3,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Descripción',
                  labelStyle:
                      TextStyle(color: textColor.withValues(alpha: 0.7)),
                  enabledBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: textColor.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: textColor),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar', style: TextStyle(color: textColor)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 154, 53, 194),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Crear'),
            ),
          ],
        );
      },
    );

    if (result == true && titleController.text.isNotEmpty) {
      try {
        await _apiService.createTodo(
          titleController.text,
          descController.text,
        );
        _loadTodos();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al crear tarea: $e')),
          );
        }
      }
    }
  }

  Future<void> _toggleTodo(Todo todo) async {
    final user = await _storage.getUser();
    bool currentStatus;
    if (user?.username == 'anyel') {
      currentStatus = todo.completedAnyel;
    } else {
      currentStatus = todo.completedAlexis;
    }

    try {
      await _apiService.updateTodoStatus(todo.id, !currentStatus);
      _loadTodos();
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteTodo(Todo todo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final themeController = ThemeProvider.of(context);
        final isDark = themeController.isDark;
        final textColor = isDark ? Colors.white : Colors.black87;
        final cardColor = isDark ? const Color(0xFF2d2640) : Colors.white;

        return AlertDialog(
          backgroundColor: cardColor,
          title: Text('Eliminar Tarea', style: TextStyle(color: textColor)),
          content: Text(
            '¿Estás seguro de eliminar "${todo.title}"?',
            style: TextStyle(color: textColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                foregroundColor: textColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Cancelar', style: TextStyle(color: textColor)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await _apiService.deleteTodo(todo.id);
        _loadTodos();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeProvider.of(context);
    final isDark = themeController.isDark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardColor = isDark ? const Color(0xFF2d2640) : Colors.white;

    return Column(
      children: [
        const Header(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: textColor.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: DropdownButton<String>(
                    value: _filter,
                    isExpanded: true,
                    underline: const SizedBox(),
                    icon: Icon(Icons.filter_list, color: textColor),
                    style: TextStyle(color: textColor, fontSize: 16),
                    dropdownColor: cardColor,
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _filter = newValue;
                        });
                        _loadTodos();
                      }
                    },
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('📋 Todas')),
                      DropdownMenuItem(
                          value: 'completed', child: Text('✅ Completadas')),
                      DropdownMenuItem(
                          value: 'incompleted', child: Text('⏳ Pendientes')),
                      DropdownMenuItem(
                          value: 'completed_by_me',
                          child: Text('🎯 Mis Completadas')),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _createTodo,
                icon: const Icon(Icons.add_circle_outline, size: 24),
                label: const Text(
                  'Nueva',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 130, 28, 170),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(textColor),
                  ),
                )
              : _todos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 64,
                              color: textColor.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          Text(
                            'No hay tareas',
                            style: TextStyle(
                              fontSize: 18,
                              color: textColor.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadTodos,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _todos.length,
                        itemBuilder: (context, index) {
                          final todo = _todos[index];
                          return _buildTodoCard(todo, cardColor, textColor);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildTodoCard(Todo todo, Color cardColor, Color textColor) {
    final user = _currentUserId;
    bool isCompletedByMe = false;
    if (user != null) {
      if (user == 1) {
        isCompletedByMe = todo.completedAnyel;
      } else {
        isCompletedByMe = todo.completedAlexis;
      }
    }

    final canDelete = todo.creatorId == user;

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    todo.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isCompletedByMe
                          ? textColor.withValues(alpha: 0.5)
                          : textColor,
                      decoration:
                          isCompletedByMe ? TextDecoration.lineThrough : null,
                      decorationThickness: isCompletedByMe ? 2.5 : null,
                      decorationColor: isCompletedByMe ? Colors.red : null,
                    ),
                  ),
                ),
                if (canDelete)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteTodo(todo),
                  ),
                Checkbox(
                  value: isCompletedByMe,
                  onChanged: todo.isCompleted ? null : (value) => _toggleTodo(todo),
                ),
              ],
            ),
            if (todo.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                todo.description,
                style: TextStyle(
                  fontSize: 14,
                  color: textColor.withValues(alpha: 0.8),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Por: ${todo.creatorUsername}',
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 16),
                Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF90EE90).withValues(alpha: 0.2),
                        border: Border.all(
                          color:
                              todo.completedAnyel ? Colors.green : Colors.grey,
                          width: 1.5,
                        ),
                      ),
                      child: ClipOval(
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Image.asset(
                            'assets/frog.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      todo.completedAnyel ? "✓" : "✗",
                      style: TextStyle(
                        fontSize: 14,
                        color: todo.completedAnyel ? Colors.green : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                        border: Border.all(
                          color:
                              todo.completedAlexis ? Colors.green : Colors.grey,
                          width: 1.5,
                        ),
                      ),
                      child: ClipOval(
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Image.asset(
                            'assets/duck.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      todo.completedAlexis ? "✓" : "✗",
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            todo.completedAlexis ? Colors.green : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (todo.isCompleted) ...[
                  const SizedBox(width: 8),
                  Text(
                    '🎉 Completada',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
