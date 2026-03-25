import 'dart:async';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../services/app_state_service.dart';
import '../utils/theme_controller.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/header.dart';
import '../models/todo.dart';
import '../models/user.dart';

enum _ConnectionStatus { online, offline }

enum _AuthBannerState { hidden, reconnecting, online, sessionExpired }

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
  User? _currentUser;
  _ConnectionStatus _connectionStatus = _ConnectionStatus.online;
  _AuthBannerState _authBannerState = _AuthBannerState.hidden;
  final Set<int> _pendingLocalIds = {};
  StreamSubscription<void>? _syncSub;
  VoidCallback? _localDataResetListener;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _syncSub = SyncService.instance.onSyncComplete.listen((_) {
      _loadTodos();
    });
    _localDataResetListener = _handleLocalDataReset;
    AppStateService.instance.localDataResetVersion
        .addListener(_localDataResetListener!);
    _loadCurrentUser();
    _loadTodos();
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _bannerTimer?.cancel();
    if (_localDataResetListener != null) {
      AppStateService.instance.localDataResetVersion
          .removeListener(_localDataResetListener!);
    }
    super.dispose();
  }

  void _handleLocalDataReset() {
    if (!mounted) return;
    setState(() {
      _todos = [];
      _pendingLocalIds.clear();
      _isLoading = false;
    });
  }

  Future<void> _loadCurrentUser() async {
    final user = await _storage.getUser();
    if (mounted) {
      setState(() => _currentUser = user);
    }
  }

  Future<void> _loadTodos() async {
    setState(() => _isLoading = true);
    final shouldShowOnline = _connectionStatus == _ConnectionStatus.offline ||
        _authBannerState == _AuthBannerState.reconnecting ||
        _authBannerState == _AuthBannerState.sessionExpired;

    try {
      final result = await _apiService.getTodos(
        status: _filter,
        sortOrder: 'desc',
        limit: 100,
      );
      if (mounted) {
        setState(() {
          _todos = result['todos'] as List<Todo>;
          _pendingLocalIds.clear();
          _isLoading = false;
          _connectionStatus = _ConnectionStatus.online;
        });
        if (shouldShowOnline) {
          _showOnlineBanner();
        }
        AppStateService.instance.setOnline(true);
      }
    } on AuthException {
      await _handleAuth401Todos();
    } on OfflineException {
      final cached = await _apiService.getCachedTodos();
      if (mounted) {
        setState(() {
          _todos = cached;
          _isLoading = false;
          _connectionStatus = _ConnectionStatus.offline;
          _authBannerState = _AuthBannerState.hidden;
        });
        AppStateService.instance.setOnline(false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar tareas: $e',
                style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleAuth401Todos() async {
    if (mounted) {
      setState(() {
        _authBannerState = _AuthBannerState.reconnecting;
      });
    }

    try {
      final result = await _apiService.getTodos(
        status: _filter,
        sortOrder: 'desc',
        limit: 100,
      );
      if (mounted) {
        setState(() {
          _todos = result['todos'] as List<Todo>;
          _pendingLocalIds.clear();
          _isLoading = false;
          _connectionStatus = _ConnectionStatus.online;
        });
        _showOnlineBanner();
        AppStateService.instance.setOnline(true);
      }
      return;
    } on AuthException {
      final cached = await _apiService.getCachedTodos();
      if (mounted) {
        setState(() {
          _todos = cached;
          _isLoading = false;
          _connectionStatus = _ConnectionStatus.online;
          _authBannerState = _AuthBannerState.sessionExpired;
        });
        AppStateService.instance.setOnline(true);
      }
      return;
    } on OfflineException {
      final cached = await _apiService.getCachedTodos();
      if (mounted) {
        setState(() {
          _todos = cached;
          _isLoading = false;
          _connectionStatus = _ConnectionStatus.offline;
          _authBannerState = _AuthBannerState.hidden;
        });
        AppStateService.instance.setOnline(false);
      }
      return;
    } catch (_) {
      final cached = await _apiService.getCachedTodos();
      if (mounted) {
        setState(() {
          _todos = cached;
          _isLoading = false;
          _authBannerState = _AuthBannerState.sessionExpired;
        });
      }
      return;
    }
  }

  void _showOnlineBanner() {
    if (!mounted) return;
    _bannerTimer?.cancel();
    setState(() {
      _authBannerState = _AuthBannerState.online;
    });
    _bannerTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _authBannerState = _AuthBannerState.hidden;
      });
    });
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

    if (result != true || titleController.text.isEmpty) return;

    final title = titleController.text;
    final description = descController.text;

    try {
      await _apiService.createTodo(title, description);
      _loadTodos();
    } on OfflineException {
      final tempId = SyncService.tempId();
      final tempTodo = SyncService.buildTempTodo(
        tempId: tempId,
        title: title,
        description: description,
        creatorId: _currentUser?.id ?? 0,
        creatorUsername: _currentUser?.username ?? '',
      );
      await SyncService.instance.enqueueTodoCreation(
          title, description, _currentUser?.username ?? '');
      if (mounted) {
        setState(() {
          _todos.insert(0, tempTodo);
          _pendingLocalIds.add(tempId);
          _connectionStatus = _ConnectionStatus.offline;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tarea guardada. Se enviará cuando tengas conexión.',
                style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear tarea: $e',
                style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleTodo(Todo todo) async {
    final isPending = _pendingLocalIds.contains(todo.id);
    if (isPending) return;

    bool currentStatus;
    if (_currentUser?.username == 'anyel') {
      currentStatus = todo.completedAnyel;
    } else {
      currentStatus = todo.completedAlexis;
    }

    try {
      final updated =
          await _apiService.updateTodoStatus(todo.id, !currentStatus);
      if (mounted) {
        setState(() {
          final idx = _todos.indexWhere((t) => t.id == todo.id);
          if (idx >= 0) {
            _todos[idx] = updated;
          }
          _pendingLocalIds.remove(todo.id);
        });
      }
    } on OfflineException {
      await SyncService.instance
          .enqueueTodoStatusUpdate(todo.id, !currentStatus);
      if (mounted) {
        final optimistic = Todo(
          id: todo.id,
          title: todo.title,
          description: todo.description,
          creatorId: todo.creatorId,
          creatorUsername: todo.creatorUsername,
          completedAnyel: _currentUser?.username == 'anyel'
              ? !currentStatus
              : todo.completedAnyel,
          completedAlexis: _currentUser?.username == 'anyel'
              ? todo.completedAlexis
              : !currentStatus,
          isCompleted: todo.isCompleted,
          createdAt: todo.createdAt,
          updatedAt: DateTime.now(),
        );
        setState(() {
          final idx = _todos.indexWhere((t) => t.id == todo.id);
          if (idx >= 0) {
            _todos[idx] = optimistic;
          }
          _pendingLocalIds.add(todo.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cambio guardado. Se enviará cuando tengas conexión.',
                style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', ''),
                style: TextStyle(color: Colors.white)),
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
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Cancelar', style: TextStyle(color: textColor)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                'Eliminar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
      );
      },
    );

    if (confirm != true) return;

    final isPending = _pendingLocalIds.contains(todo.id);
    if (isPending) {
      setState(() {
        _todos.removeWhere((t) => t.id == todo.id);
        _pendingLocalIds.remove(todo.id);
      });
      return;
    }

    try {
      await _apiService.deleteTodo(todo.id);
      _loadTodos();
    } on OfflineException {
      await SyncService.instance.enqueueTodoDeletion(todo.id);
      if (mounted) {
        setState(() {
          _todos.removeWhere((t) => t.id == todo.id);
          _pendingLocalIds.remove(todo.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Eliminación pendiente. Se aplicará cuando tengas conexión.',
                style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e',
                style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
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
        _buildAuthBanner(),
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
                        setState(() => _filter = newValue);
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
                      borderRadius: BorderRadius.circular(8)),
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

  Widget _buildAuthBanner() {
    if (_authBannerState == _AuthBannerState.hidden) {
      return const SizedBox.shrink();
    }

    if (_authBannerState == _AuthBannerState.reconnecting) {
      return Container(
        width: double.infinity,
        color: Colors.orange[700],
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        child: const Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Reconectando sesión...',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_authBannerState == _AuthBannerState.online) {
      return Container(
        width: double.infinity,
        color: Colors.green[700],
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text(
              'Conexión restablecida',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      color: Colors.red[700],
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sesión expirada. Cierra sesión y vuelve a iniciar.',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoCard(Todo todo, Color cardColor, Color textColor) {
    final isPending = _pendingLocalIds.contains(todo.id);
    final userId = _currentUser?.id;
    bool isCompletedByMe = false;
    if (userId != null) {
      isCompletedByMe =
          userId == 1 ? todo.completedAnyel : todo.completedAlexis;
    }

    final canDelete = todo.creatorId == userId || isPending;

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
                  onChanged: (isPending || todo.isCompleted)
                      ? null
                      : (_) => _toggleTodo(todo),
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
                _buildCompletionDot(todo.completedAnyel, 'assets/frog.png',
                    const Color(0xFF90EE90)),
                const SizedBox(width: 4),
                Text(
                  todo.completedAnyel ? '✓' : '✗',
                  style: TextStyle(
                    fontSize: 14,
                    color: todo.completedAnyel ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                _buildCompletionDot(todo.completedAlexis, 'assets/duck.png',
                    const Color(0xFFFFD700)),
                const SizedBox(width: 4),
                Text(
                  todo.completedAlexis ? '✓' : '✗',
                  style: TextStyle(
                    fontSize: 14,
                    color: todo.completedAlexis ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (todo.isCompleted) ...[
                  const SizedBox(width: 8),
                  const Text(
                    '🎉 Completada',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                const Spacer(),
                if (isPending)
                  Row(
                    spacing: 3,
                    children: [
                      Text(
                        "Enviando...",
                        style:
                            TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                      ),
                      Icon(
                        Icons.schedule,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ],
                  )
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionDot(bool completed, String asset, Color color) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.2),
        border: Border.all(
          color: completed ? Colors.green : Colors.grey,
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Image.asset(asset, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
