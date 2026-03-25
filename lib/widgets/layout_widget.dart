import 'dart:async';
import 'package:love_app/screens/messages_screen.dart';
import 'package:love_app/screens/journey_screen.dart';
import 'package:love_app/screens/alarms_screen.dart';
import 'package:love_app/screens/tasks_screen.dart';
import 'package:love_app/screens/home_screen.dart';
import 'package:love_app/screens/settings_screen.dart';
import 'package:love_app/services/app_state_service.dart';
import 'package:love_app/services/chat_realtime_service.dart';
import 'package:love_app/services/sync_service.dart';
import 'package:love_app/widgets/background.dart';
import 'package:flutter/material.dart';

class LayoutWidget extends StatefulWidget {
  const LayoutWidget({super.key});

  @override
  State<LayoutWidget> createState() => _LayoutWidgetState();
}

class _LayoutWidgetState extends State<LayoutWidget> {
  int _index = 0;

  late final List<Widget> _pages;
  VoidCallback? _requestedTabListener;

  @override
  void initState() {
    super.initState();
    _index = AppStateService.instance.consumeRequestedTab() ?? 0;
    _pages = const [
      HomeScreen(),
      JourneyScreen(),
      AlarmsScreen(),
      TasksScreen(),
      MessagesScreen(),
      SettingsScreen(),
    ];
    AppStateService.instance.setCurrentTab(_index);
    _requestedTabListener = _handleRequestedTab;
    AppStateService.instance.requestedTab.addListener(_requestedTabListener!);
    unawaited(ChatRealtimeService.instance.connect().catchError((_) {}));
    unawaited(SyncService.instance.syncOnAppLaunch().catchError((_) {}));
  }

  void _handleRequestedTab() {
    final requestedTab = AppStateService.instance.consumeRequestedTab();
    if (requestedTab == null || !mounted || requestedTab == _index) {
      return;
    }

    setState(() => _index = requestedTab);
    AppStateService.instance.setCurrentTab(requestedTab);
  }

  @override
  void dispose() {
    if (_requestedTabListener != null) {
      AppStateService.instance.requestedTab
          .removeListener(_requestedTabListener!);
    }
    ChatRealtimeService.instance.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerColor = isDark
        ? const Color(0xFF0C0522)
        : const Color.fromARGB(255, 255, 255, 255);
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: headerColor,
      body: Stack(
        children: [
          const Background(),
          if (topInset > 0)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: topInset,
                color: headerColor,
              ),
            ),
          SafeArea(
            child: IndexedStack(
              index: _index,
              children: _pages,
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          AppStateService.instance.setCurrentTab(i);
        },
        backgroundColor: headerColor,
        destinations: [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Inicio'),
          NavigationDestination(
              icon: Icon(Icons.timeline_outlined),
              selectedIcon: Icon(Icons.timeline),
              label: 'Trayecto'),
          NavigationDestination(
              icon: Icon(Icons.alarm_outlined),
              selectedIcon: Icon(Icons.alarm),
              label: 'Alarmas'),
          NavigationDestination(
              icon: Icon(Icons.checklist_outlined),
              selectedIcon: Icon(Icons.checklist),
              label: 'Tareas'),
          NavigationDestination(
              icon: ValueListenableBuilder<int>(
                valueListenable: AppStateService.instance.unreadMessages,
                builder: (context, unread, _) {
                  return _buildMessagesIcon(
                    unread: unread,
                    selected: false,
                  );
                },
              ),
              selectedIcon: ValueListenableBuilder<int>(
                valueListenable: AppStateService.instance.unreadMessages,
                builder: (context, unread, _) {
                  return _buildMessagesIcon(
                    unread: unread,
                    selected: true,
                  );
                },
              ),
              label: 'Mensajes'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Opciones'),
        ],
      ),
    );
  }

  Widget _buildMessagesIcon({required int unread, required bool selected}) {
    final icon = selected ? Icons.chat_bubble : Icons.chat_bubble_outline;
    if (unread <= 0) {
      return Icon(icon);
    }

    final badgeLabel = unread > 99 ? '99+' : unread.toString();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        Positioned(
          right: -9,
          top: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF8E44AD),
              borderRadius: BorderRadius.circular(10),
            ),
            constraints: const BoxConstraints(minWidth: 18, minHeight: 16),
            child: Text(
              badgeLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
