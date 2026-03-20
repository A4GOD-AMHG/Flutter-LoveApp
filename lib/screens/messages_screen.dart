import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../utils/theme_controller.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/header.dart';
import '../models/message.dart';
import '../models/user.dart';
import 'dart:convert';

enum _ConnectionStatus { online, offline }

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final ApiService _apiService = ApiService();
  final StorageService _storage = StorageService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Message> _messages = [];
  WebSocketChannel? _channel;
  bool _isLoading = true;
  int? _currentUserId;
  String? _currentUsername;
  User? _currentUserFull;
  _ConnectionStatus _connectionStatus = _ConnectionStatus.online;
  final Set<int> _pendingLocalIds = {};
  StreamSubscription<void>? _syncSub;

  int _currentPage = 1;
  bool _hasMoreMessages = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _syncSub = SyncService.instance.onSyncComplete.listen((_) {
      _loadMessages();
    });
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadCurrentUser();
    await _loadMessages();
    await _connectWebSocket();
  }

  Future<void> _loadCurrentUser() async {
    final user = await _storage.getUser();
    setState(() {
      _currentUserId = user?.id;
      _currentUsername = user?.username;
      _currentUserFull = user;
    });
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await _apiService.getConversation(page: 1, perPage: 10);
      setState(() {
        _messages = messages.reversed.toList();
        _pendingLocalIds.clear();
        _isLoading = false;
        _currentPage = 1;
        _hasMoreMessages = messages.length == 10;
        _connectionStatus = _ConnectionStatus.online;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    } on OfflineException {
      final cached = await _apiService.getCachedMessages();
      setState(() {
        _messages = cached;
        _isLoading = false;
        _hasMoreMessages = false;
        _connectionStatus = _ConnectionStatus.offline;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar mensajes: $e')),
        );
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels <= 200 &&
        !_isLoadingMore &&
        _hasMoreMessages) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages) return;

    setState(() => _isLoadingMore = true);

    final scrollOffset = _scrollController.offset;

    try {
      final messages = await _apiService.getConversation(
        page: _currentPage + 1,
        perPage: 10,
      );

      if (mounted) {
        setState(() {
          _currentPage++;
          _hasMoreMessages = messages.length == 10;
          _messages.insertAll(0, messages.reversed);
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            final newOffset = _scrollController.position.maxScrollExtent -
                (_scrollController.position.maxScrollExtent - scrollOffset);
            _scrollController.jumpTo(newOffset + (messages.length * 80.0));
          }
        });

        await Future.delayed(const Duration(milliseconds: 300));

        if (mounted) {
          setState(() => _isLoadingMore = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar más mensajes: $e')),
        );
      }
    }
  }

  Future<void> _connectWebSocket() async {
    try {
      final token = await _storage.getToken();
      if (token != null) {
        final configuredWs = await _apiService.getWebSocketUrl();
        final uri = Uri.parse(configuredWs);
        final wsUrl = uri.replace(
          queryParameters: {
            ...uri.queryParameters,
            'token': token,
          },
        );

        try {
          _channel = WebSocketChannel.connect(
            wsUrl,
          );

          _channel!.stream.listen(
            (data) {
              try {
                final wsData = jsonDecode(data);

                if (wsData['type'] != 'message_sent' ||
                    wsData['payload'] == null) {
                  return;
                }

                final messageData = wsData['payload'];

                if (messageData['content'] == null ||
                    messageData['content'].toString().trim().isEmpty) {
                  return;
                }

                final message = Message.fromJson(messageData);

                if (mounted && message.senderId != _currentUserId) {
                  setState(() {
                    _messages.add(message);
                  });
                  _scrollToBottom();
                }
              } catch (e) {
                // Silently handle parsing errors
              }
            },
            onError: (error) {
              // Silently handle WebSocket errors
            },
            onDone: () {
              // Connection closed
            },
            cancelOnError: false,
          );
        } catch (wsError) {
          // WebSocket connection failed, messages will load via HTTP
        }
      }
    } catch (e) {
      // General WebSocket error
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final content = _messageController.text.trim();
    _messageController.clear();

    try {
      final message = await _apiService.sendMessage(content);
      if (mounted) {
        setState(() => _messages.add(message));
        _scrollToBottom();
      }
    } on OfflineException {
      await SyncService.instance.enqueueMessageSend(content);
      final tempId = SyncService.tempId();
      final now = DateTime.now();
      final sender = _currentUserFull ??
          User(
            id: _currentUserId ?? 0,
            username: _currentUsername ?? '',
            name: _currentUsername ?? '',
            createdAt: now,
            updatedAt: now,
          );
      final tempMessage = Message(
        id: tempId,
        senderId: sender.id,
        receiverId: 0,
        sender: sender,
        receiver: sender,
        content: content,
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      );
      if (mounted) {
        setState(() {
          _messages.add(tempMessage);
          _pendingLocalIds.add(tempId);
          _connectionStatus = _ConnectionStatus.offline;
        });
        _scrollToBottom();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Mensaje guardado. Se enviará cuando tengas conexión.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar mensaje: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _scrollController.removeListener(_onScroll);
    _channel?.sink.close();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
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
        if (_connectionStatus == _ConnectionStatus.offline)
          Container(
            width: double.infinity,
            color: Colors.grey[700],
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            child: const Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text(
                  'Sin conexión — mostrando mensajes guardados',
                  style: TextStyle(color: Colors.white, fontSize: 13),
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
              : _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '💬',
                            style: const TextStyle(fontSize: 64),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No hay mensajes aún',
                            style: TextStyle(
                              fontSize: 18,
                              color: textColor.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Escribe algo para comenzar la conversación',
                            style: TextStyle(
                              fontSize: 14,
                              color: textColor.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length +
                          (_isLoadingMore || _hasMoreMessages ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == 0 &&
                            (_isLoadingMore || _hasMoreMessages)) {
                          return _buildLoadingIndicator(textColor);
                        }

                        final messageIndex =
                            (_isLoadingMore || _hasMoreMessages)
                                ? index - 1
                                : index;
                        final message = _messages[messageIndex];
                        final isMe = message.senderId == _currentUserId;

                        final showDateSeparator = messageIndex == 0 ||
                            !_isSameDay(_messages[messageIndex - 1].createdAt,
                                message.createdAt);

                        return Column(
                          children: [
                            if (showDateSeparator)
                              _buildDateSeparator(message.createdAt, textColor),
                            _buildMessageBubble(
                              message,
                              isMe,
                              textColor,
                              cardColor,
                            ),
                          ],
                        );
                      },
                    ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0d0818) : const Color(0xFFE8E8E8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: TextStyle(color: textColor),
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      hintStyle: TextStyle(
                        color: textColor.withValues(alpha: 0.5),
                      ),
                      filled: true,
                      fillColor:
                          isDark ? const Color(0xFF1a1625) : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF9B59B6), Color(0xFF8E44AD)],
                    ),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(
    Message message,
    bool isMe,
    Color textColor,
    Color cardColor,
  ) {
    final isPending = _pendingLocalIds.contains(message.id);
    final bgColor = isMe
        ? (isPending ? Colors.orange[700]! : const Color(0xFF9B59B6))
        : cardColor;
    final msgTextColor = isMe ? Colors.white : textColor;

    final displayUsername = isMe ? _currentUsername : message.sender.username;
    final avatarPath =
        displayUsername == 'anyel' ? 'assets/frog.png' : 'assets/duck.png';
    final avatarColor = displayUsername == 'anyel'
        ? const Color(0xFF90EE90)
        : const Color(0xFFFFD700);
    final time = _formatTime(message.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: avatarColor.withValues(alpha: 0.3),
                border: Border.all(color: avatarColor, width: 2),
              ),
              child: ClipOval(
                child: Padding(
                  padding: const EdgeInsets.all(1),
                  child: Image.asset(avatarPath, fit: BoxFit.contain),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.sender.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: msgTextColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 16,
                      color: msgTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 10,
                          color: msgTextColor.withValues(alpha: 0.6),
                        ),
                      ),
                      if (isPending) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.schedule,
                          size: 10,
                          color: msgTextColor.withValues(alpha: 0.7),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: avatarColor.withValues(alpha: 0.3),
                border: Border.all(color: avatarColor, width: 2),
              ),
              child: ClipOval(
                child: Padding(
                  padding: const EdgeInsets.all(1),
                  child: Image.asset(avatarPath, fit: BoxFit.contain),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Widget _buildLoadingIndicator(Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: _isLoadingMore
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        textColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Cargando mensajes...',
                    style: TextStyle(
                      fontSize: 13,
                      color: textColor.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              )
            : Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: textColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Desliza hacia arriba para cargar más',
                  style: TextStyle(
                    fontSize: 11,
                    color: textColor.withValues(alpha: 0.5),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildDateSeparator(DateTime date, Color textColor) {
    final now = DateTime.now();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));

    String label;
    if (_isSameDay(date, now)) {
      label = 'Hoy';
    } else if (_isSameDay(date, yesterday)) {
      label = 'Ayer';
    } else {
      final months = [
        'Enero',
        'Febrero',
        'Marzo',
        'Abril',
        'Mayo',
        'Junio',
        'Julio',
        'Agosto',
        'Septiembre',
        'Octubre',
        'Noviembre',
        'Diciembre'
      ];
      label = '${date.day} de ${months[date.month - 1]}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: textColor.withValues(alpha: 0.3),
              thickness: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: textColor.withValues(alpha: 0.3),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }
}
