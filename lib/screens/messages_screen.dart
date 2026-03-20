import 'dart:async';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../services/database_service.dart';
import '../services/app_state_service.dart';
import '../services/chat_realtime_service.dart';
import '../utils/theme_controller.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/header.dart';
import '../models/message.dart';
import '../models/user.dart';

enum _ConnectionStatus { online, offline }
enum _AuthBannerState { hidden, reconnecting, online, sessionExpired }

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final ApiService _apiService = ApiService();
  final StorageService _storage = StorageService();
  final DatabaseService _db = DatabaseService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Message> _messages = [];
  bool _isLoading = true;
  int? _currentUserId;
  String? _currentUsername;
  User? _currentUserFull;
  _ConnectionStatus _connectionStatus = _ConnectionStatus.online;
  _AuthBannerState _authBannerState = _AuthBannerState.hidden;
  final Set<int> _pendingLocalIds = {};
  StreamSubscription<void>? _syncSub;
  StreamSubscription<ChatRealtimeEvent>? _realtimeSub;
  VoidCallback? _tabListener;
  VoidCallback? _localDataResetListener;
  Timer? _bannerTimer;

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
    _realtimeSub = ChatRealtimeService.instance.events.listen(
      _applyRealtimeEvent,
    );
    _tabListener = _handleTabChange;
    AppStateService.instance.currentTab.addListener(_tabListener!);
    _localDataResetListener = _handleLocalDataReset;
    AppStateService.instance.localDataResetVersion
        .addListener(_localDataResetListener!);
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadCurrentUser();
    await _loadMessages();
  }

  void _handleTabChange() {
    if (AppStateService.instance.currentTab.value == 4) {
      _markAllVisibleAsRead();
    }
  }

  void _handleLocalDataReset() {
    if (!mounted) return;
    setState(() {
      _messages = [];
      _pendingLocalIds.clear();
      _isLoading = false;
      _isLoadingMore = false;
      _hasMoreMessages = false;
      _currentPage = 1;
      _authBannerState = _AuthBannerState.hidden;
    });
  }

  void _applyRealtimeEvent(ChatRealtimeEvent event) {
    if (!mounted) return;

    switch (event.type) {
      case 'message_sent':
        final incoming = event.message;
        if (incoming == null) return;
        final existingIndex = _messages.indexWhere((m) => m.id == incoming.id);
        setState(() {
          if (existingIndex >= 0) {
            _messages[existingIndex] = incoming;
          } else {
            _messages.add(incoming);
          }
        });
        if (incoming.senderId != _currentUserId &&
            AppStateService.instance.currentTab.value == 4) {
          _scrollToBottom();
        }
      case 'message_deleted':
        final id = event.messageId;
        if (id == null) return;
        setState(() => _messages.removeWhere((m) => m.id == id));
      case 'message_updated':
      case 'message_status':
        final id = event.messageId;
        final status = event.status;
        if (id == null || status == null) return;
        final idx = _messages.indexWhere((m) => m.id == id);
        if (idx < 0) return;
        final old = _messages[idx];
        setState(() {
          _messages[idx] = Message(
            id: old.id,
            senderId: old.senderId,
            receiverId: old.receiverId,
            sender: old.sender,
            receiver: old.receiver,
            content: old.content,
            status: status,
            createdAt: old.createdAt,
            updatedAt: event.updatedAt ?? DateTime.now(),
          );
        });
    }
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
    final shouldShowOnline = _connectionStatus == _ConnectionStatus.offline ||
        _authBannerState == _AuthBannerState.reconnecting ||
        _authBannerState == _AuthBannerState.sessionExpired;
    try {
      final messages = await _apiService.getConversation(page: 1, perPage: 10);
      final pendingIds = messages
          .where((m) => m.status == 'pending' || m.id < 0)
          .map((m) => m.id)
          .toSet();
      setState(() {
        _messages = messages.reversed.toList();
        _pendingLocalIds
          ..clear()
          ..addAll(pendingIds);
        _isLoading = false;
        _currentPage = 1;
        _hasMoreMessages = messages.length == 10;
        _connectionStatus = _ConnectionStatus.online;
      });
      if (shouldShowOnline) {
        _showOnlineBanner();
      }
      AppStateService.instance.setOnline(true);
      await _syncUnreadBadge();
      if (AppStateService.instance.currentTab.value == 4) {
        await _markAllVisibleAsRead();
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    } on AuthException {
      await _handleAuth401Messages();
    } on OfflineException {
      final cached = await _apiService.getCachedMessages();
      final pendingIds = cached
          .where((m) => m.status == 'pending' || m.id < 0)
          .map((m) => m.id)
          .toSet();
      setState(() {
        _messages = cached;
        _pendingLocalIds
          ..clear()
          ..addAll(pendingIds);
        _isLoading = false;
        _hasMoreMessages = false;
        _connectionStatus = _ConnectionStatus.offline;
        _authBannerState = _AuthBannerState.hidden;
      });
      AppStateService.instance.setOnline(false);
      await _syncUnreadBadge();
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
          SnackBar(
            content: Text('Error al cargar mensajes: $e', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleAuth401Messages() async {
    if (mounted) {
      setState(() {
        _authBannerState = _AuthBannerState.reconnecting;
      });
    }

    try {
      final messages = await _apiService.getConversation(page: 1, perPage: 10);
      final pendingIds = messages
          .where((m) => m.status == 'pending' || m.id < 0)
          .map((m) => m.id)
          .toSet();
      if (mounted) {
        setState(() {
          _messages = messages.reversed.toList();
          _pendingLocalIds
            ..clear()
            ..addAll(pendingIds);
          _isLoading = false;
          _currentPage = 1;
          _hasMoreMessages = messages.length == 10;
          _connectionStatus = _ConnectionStatus.online;
        });
        _showOnlineBanner();
        AppStateService.instance.setOnline(true);
      }
      await _syncUnreadBadge();
      return;
    } on AuthException {
      final cached = await _apiService.getCachedMessages();
      final pendingIds = cached
          .where((m) => m.status == 'pending' || m.id < 0)
          .map((m) => m.id)
          .toSet();
      if (mounted) {
        setState(() {
          _messages = cached;
          _pendingLocalIds
            ..clear()
            ..addAll(pendingIds);
          _isLoading = false;
          _hasMoreMessages = false;
          _connectionStatus = _ConnectionStatus.online;
          _authBannerState = _AuthBannerState.sessionExpired;
        });
        AppStateService.instance.setOnline(true);
      }
      await _syncUnreadBadge();
      return;
    } on OfflineException {
      final cached = await _apiService.getCachedMessages();
      final pendingIds = cached
          .where((m) => m.status == 'pending' || m.id < 0)
          .map((m) => m.id)
          .toSet();
      if (mounted) {
        setState(() {
          _messages = cached;
          _pendingLocalIds
            ..clear()
            ..addAll(pendingIds);
          _isLoading = false;
          _hasMoreMessages = false;
          _connectionStatus = _ConnectionStatus.offline;
          _authBannerState = _AuthBannerState.hidden;
        });
        AppStateService.instance.setOnline(false);
      }
      await _syncUnreadBadge();
      return;
    } catch (_) {
      final cached = await _apiService.getCachedMessages();
      final pendingIds = cached
          .where((m) => m.status == 'pending' || m.id < 0)
          .map((m) => m.id)
          .toSet();
      if (mounted) {
        setState(() {
          _messages = cached;
          _pendingLocalIds
            ..clear()
            ..addAll(pendingIds);
          _isLoading = false;
          _hasMoreMessages = false;
          _authBannerState = _AuthBannerState.sessionExpired;
        });
        AppStateService.instance.setOnline(false);
      }
      await _syncUnreadBadge();
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
        final prevExtent = _scrollController.hasClients
            ? _scrollController.position.maxScrollExtent
            : 0.0;
        setState(() {
          _currentPage++;
          _hasMoreMessages = messages.length == 10;
          _messages.insertAll(0, messages.reversed);
        });
        await Future.delayed(const Duration(milliseconds: 100));
        if (_scrollController.hasClients) {
          final newExtent = _scrollController.position.maxScrollExtent;
          final delta = newExtent - prevExtent;
          final target = scrollOffset + delta;
          _scrollController.jumpTo(target.clamp(
            _scrollController.position.minScrollExtent,
            _scrollController.position.maxScrollExtent,
          ));
        }
        if (mounted) {
          setState(() => _isLoadingMore = false);
        }
      }
    } catch (e) {
      if (e is AuthException) {
        await _handleAuth401Messages();
        if (mounted) {
          setState(() => _isLoadingMore = false);
        }
        return;
      }
      if (mounted) {
        setState(() => _isLoadingMore = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar más mensajes: $e', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markAllVisibleAsRead() async {
    if (_currentUserId == null) return;

    final unreadIds = _messages
        .where((m) => m.senderId != _currentUserId && m.status != 'read')
        .map((m) => m.id)
        .toList();
    if (unreadIds.isEmpty) {
      AppStateService.instance.resetUnreadMessages();
      return;
    }

    await _db.markIncomingMessagesAsRead(_currentUserId!);
    if (mounted) {
      setState(() {
        _messages = _messages
            .map(
              (m) => m.senderId != _currentUserId && m.status != 'read'
                  ? Message(
                      id: m.id,
                      senderId: m.senderId,
                      receiverId: m.receiverId,
                      sender: m.sender,
                      receiver: m.receiver,
                      content: m.content,
                      status: 'read',
                      createdAt: m.createdAt,
                      updatedAt: DateTime.now(),
                    )
                  : m,
            )
            .toList();
      });
    }

    for (final id in unreadIds) {
      try {
        await _apiService.markMessageRead(id);
      } catch (_) {}
    }

    await _syncUnreadBadge();
  }

  Future<void> _syncUnreadBadge() async {
    try {
      final unread = await _apiService.getUnreadCount();
      AppStateService.instance.setUnreadMessages(unread);
    } catch (_) {
      if (_currentUserId == null) return;
      final unread = await _db.getUnreadMessagesCount(_currentUserId!);
      AppStateService.instance.setUnreadMessages(unread);
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
        setState(() {
          final existingIndex = _messages.indexWhere((m) => m.id == message.id);
          if (existingIndex >= 0) {
            _messages[existingIndex] = message;
          } else {
            _messages.add(message);
          }
        });
        _scrollToBottom();
      }
    } on OfflineException {
      final tempId = SyncService.tempId();
      await SyncService.instance.enqueueMessageSend(content, tempId: tempId);
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
      await _db.insertMessage(tempMessage);
      if (mounted) {
        setState(() {
          _messages.add(tempMessage);
          _pendingLocalIds.add(tempId);
          _connectionStatus = _ConnectionStatus.offline;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar mensaje: $e', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _realtimeSub?.cancel();
    _bannerTimer?.cancel();
    if (_tabListener != null) {
      AppStateService.instance.currentTab.removeListener(_tabListener!);
    }
    if (_localDataResetListener != null) {
      AppStateService.instance.localDataResetVersion
          .removeListener(_localDataResetListener!);
    }
    _scrollController.removeListener(_onScroll);
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
        _buildAuthBanner(),
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
                            context,
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

  Widget _buildAuthBanner() {
    if (_authBannerState == _AuthBannerState.hidden) {
      return const SizedBox.shrink();
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

  Widget _buildMessageBubble(
    BuildContext context,
    Message message,
    bool isMe,
    Color textColor,
    Color cardColor,
  ) {
    final isPending = _pendingLocalIds.contains(message.id);
    final sentColor = const Color(0xFF9B59B6);
    final pendingColor = const Color(0xFF7C4DFF);
    final bgColor = isMe ? (isPending ? pendingColor : sentColor) : cardColor;
    final msgTextColor = isMe ? Colors.white : textColor;

    final displayUsername = isMe ? _currentUsername : message.sender.username;
    final avatarPath =
        displayUsername == 'anyel' ? 'assets/frog.png' : 'assets/duck.png';
    final avatarColor = displayUsername == 'anyel'
        ? const Color(0xFF90EE90)
        : const Color(0xFFFFD700);
    final time = _formatTime(message.createdAt);

    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.65;
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
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxBubbleWidth),
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
                    if (isPending)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 12,
                              color: Colors.purple[100],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Enviando...',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.purple[100],
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded(
                          child: Text(
                            time,
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              fontSize: 10,
                              color: msgTextColor.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        if (isMe)
                          _buildOutgoingStatusIcon(
                            status: message.status,
                            isPending: isPending,
                            color: msgTextColor,
                          ),
                      ],
                    ),
                  ],
                ),
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

  Widget _buildOutgoingStatusIcon({
    required String status,
    required bool isPending,
    required Color color,
  }) {
    if (isPending || status == 'pending') {
      return Icon(
        Icons.schedule,
        size: 12,
        color: Colors.purpleAccent.shade100,
      );
    }

    switch (status) {
      case 'read':
        return const Icon(
          Icons.done_all,
          size: 14,
          color: Colors.white,
        );
      case 'delivered':
        return const Icon(
          Icons.done_all,
          size: 14,
          color: Color(0xFFEDEDED),
        );
      case 'sent':
      default:
        return Icon(
          Icons.done,
          size: 13,
          color: color.withValues(alpha: 0.95),
        );
    }
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
