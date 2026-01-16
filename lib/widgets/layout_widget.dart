import 'package:love_app/screens/messages_screen.dart';
import 'package:love_app/screens/journey_screen.dart';
import 'package:love_app/screens/alarms_screen.dart';
import 'package:love_app/screens/notes_screen.dart';
import 'package:love_app/screens/home_screen.dart';
import 'package:love_app/widgets/background.dart';
import 'package:flutter/material.dart';

class LayoutWidget extends StatefulWidget {
  const LayoutWidget({super.key});

  @override
  State<LayoutWidget> createState() => _LayoutWidgetState();
}

class _LayoutWidgetState extends State<LayoutWidget> {
  int _index = 0;

  static const List<Widget> _pages = [
    HomeScreen(),
    JourneyScreen(),
    AlarmsScreen(),
    NotesScreen(),
    MessagesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? Color(0xFF0C0522) : Color.fromARGB(255, 255, 255, 255),
      body: Stack(
        children: [
          const Background(),
          SafeArea(child: _pages[_index]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor:
            isDark ? Color(0xFF0C0522) : Color.fromARGB(255, 255, 255, 255),
        destinations: const [
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
              label: 'Pendientes'),
          NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble),
              label: 'Mensajes'),
        ],
      ),
    );
  }
}
