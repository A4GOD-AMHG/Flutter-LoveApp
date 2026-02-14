import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/storage_service.dart';
import '../utils/theme_controller.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/header.dart';
import '../models/message.dart';
import 'dart:convert';

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

  @override
  void initState() {
    super.initState();
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
    });
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await _apiService.getConversation(perPage: 100);
      setState(() {
        _messages = messages.reversed.toList();
        _isLoading = false;
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

  Future<void> _connectWebSocket() async {
    try {
      final token = await _storage.getToken();
      if (token != null) {
        final wsUrl = '${_apiService.getWebSocketUrl()}?token=$token';
        
        try {
          _channel = WebSocketChannel.connect(
            Uri.parse(wsUrl),
          );

          _channel!.stream.listen(
            (data) {
              try {
                print('📩 WebSocket RAW data: $data');
                final messageData = jsonDecode(data);
                print('📦 Parsed messageData: $messageData');
                final message = Message.fromJson(messageData);
                print('✉️ Message object - senderId: ${message.senderId}, currentUserId: $_currentUserId, content: "${message.content}"');
                
                if (mounted && message.senderId != _currentUserId) {
                  print('✅ Adding message from other user');
                  setState(() {
                    _messages.add(message);
                  });
                  _scrollToBottom();
                } else {
                  print('❌ Ignoring message (own message or not mounted)');
                }
              } catch (e) {
                print('❗ Error parsing WebSocket message: $e');
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
      print('📤 Sent message - senderId: ${message.senderId}, currentUserId: $_currentUserId, content: "${message.content}"');
      
      if (mounted) {
        setState(() {
          _messages.add(message);
        });
        _scrollToBottom();
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
    final bgColor = isDark ? const Color(0xFF1a1625) : const Color(0xFFF5F5F5);

    return Column(
      children: [
        const Header(),
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
                              color: textColor.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Escribe algo para comenzar la conversación',
                            style: TextStyle(
                              fontSize: 14,
                              color: textColor.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final isMe = message.senderId == _currentUserId;
                        return _buildMessageBubble(
                          message,
                          isMe,
                          textColor,
                          cardColor,
                        );
                      },
                    ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0d0818) : const Color(0xFFE8E8E8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
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
                        color: textColor.withOpacity(0.5),
                      ),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1a1625) : Colors.white,
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
    final alignment = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bgColor = isMe
        ? const Color(0xFF9B59B6)
        : cardColor;
    final msgTextColor = isMe ? Colors.white : textColor;
    
    final displayUsername = isMe ? _currentUsername : message.sender.username;
    final avatarPath = displayUsername == 'anyel' 
        ? 'assets/frog.png' 
        : 'assets/duck.png';
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
                color: avatarColor.withOpacity(0.3),
                border: Border.all(color: avatarColor, width: 2),
              ),
              child: ClipOval(
                child: Padding(
                  padding: const EdgeInsets.all(6),
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
                          color: msgTextColor.withOpacity(0.8),
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
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 10,
                      color: msgTextColor.withOpacity(0.6),
                    ),
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
                color: avatarColor.withOpacity(0.3),
                border: Border.all(color: avatarColor, width: 2),
              ),
              child: ClipOval(
                child: Padding(
                  padding: const EdgeInsets.all(6),
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
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inDays > 0) {
      return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}
