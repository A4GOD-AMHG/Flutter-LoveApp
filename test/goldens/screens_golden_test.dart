// Goldens de las pantallas principales. Regenerar con:
//   flutter test --update-goldens test/goldens
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:love_app/models/message.dart';
import 'package:love_app/models/todo.dart';
import 'package:love_app/models/user.dart';
import 'package:love_app/screens/login_screen.dart';
import 'package:love_app/screens/messages_screen.dart';
import 'package:love_app/screens/settings_screen.dart';
import 'package:love_app/screens/tasks_screen.dart';
import 'package:love_app/services/app_state_service.dart';
import 'package:love_app/services/database_service.dart';
import 'package:love_app/utils/theme_controller.dart';
import 'package:love_app/widgets/connection_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Simula "sin red": toda petición HTTP falla como un SocketException real,
/// así las pantallas muestran los datos cacheados en SQLite.
class _NoNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw const SocketException('sin red (golden test)');
}

final _base = DateTime(2026, 10, 26, 9, 30);
User _user(int id, String username, String name) => User(
    id: id, username: username, name: name, createdAt: _base, updatedAt: _base);
final _anyel = _user(1, 'anyel', 'Anyel');
final _alexis = _user(2, 'alexis', 'Alexis');

Message _msg(
        int id, User from, User to, String text, String status, int minute) =>
    Message(
      id: id,
      senderId: from.id,
      receiverId: to.id,
      sender: from,
      receiver: to,
      content: text,
      status: status,
      createdAt: _base.add(Duration(minutes: minute)),
      updatedAt: _base.add(Duration(minutes: minute)),
    );

Todo _todo(int id, String title, User creator,
        {bool anyel = false, bool alexis = false}) =>
    Todo(
      id: id,
      title: title,
      description: 'Descripción de "$title"',
      creatorId: creator.id,
      creatorUsername: creator.username,
      completedAnyel: anyel,
      completedAlexis: alexis,
      isCompleted: anyel && alexis,
      createdAt: _base.add(Duration(hours: id)),
      updatedAt: _base.add(Duration(hours: id)),
    );

Future<void> _loadFont() async {
  final loader = FontLoader('ComicNeue');
  for (final style in ['Regular', 'Bold']) {
    loader.addFont(rootBundle.load('assets/google_fonts/ComicNeue-$style.ttf'));
  }
  await loader.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}

Future<void> _session(User user) async {
  SharedPreferences.setMockInitialValues({
    'auth_token': 'golden-token',
    'user_data': jsonEncode(user.toJson()),
    'server_host': 'http://127.0.0.1:1/',
  });
  final db = DatabaseService();
  await db.saveMessages([
    _msg(1, _alexis, _anyel, 'Buenos días mi amor ☀️', 'read', 0),
    _msg(2, _anyel, _alexis, 'Buenos días! Ya desayunaste?', 'read', 2),
    _msg(3, _alexis, _anyel, 'Todavía no, ¿vamos juntos?', 'read', 3),
    _msg(4, _anyel, _alexis, 'Sí! Te veo en 10 min', 'delivered', 5),
    _msg(5, _anyel, _alexis, 'Llevo el paraguas', 'sent', 6),
  ]);
  await db.saveTodos([
    _todo(1, 'Comprar flores', _alexis, anyel: true, alexis: true),
    _todo(2, 'Reservar cena', _anyel, anyel: true),
    _todo(3, 'Ver una película', _alexis),
  ]);
}

Widget _app(Widget screen, {bool dark = true}) {
  final brightness = dark ? Brightness.dark : Brightness.light;
  return ThemeProvider(
    controller: ThemeController(dark ? ThemeMode.dark : ThemeMode.light),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple, brightness: brightness),
        fontFamily: 'ComicNeue',
        useMaterial3: true,
        scaffoldBackgroundColor:
            dark ? const Color(0xFF1C1E2A) : const Color(0xFFF7F5FF),
      ),
      home: Scaffold(body: SafeArea(child: screen)),
    ),
  );
}

Future<void> _pumpGolden(WidgetTester tester, Widget screen, String name,
    {bool dark = true}) async {
  await tester.pumpWidget(_app(screen, dark: dark));
  // Las pantallas cargan de SQLite en microtareas; las animaciones se repiten,
  // así que se avanza tiempo fijo en lugar de pumpAndSettle.
  for (var i = 0; i < 10; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 200));
  }
  await expectLater(
      find.byType(MaterialApp), matchesGoldenFile('images/$name.png'));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    HttpOverrides.global = _NoNetwork();
    await _loadFont();
  });

  setUp(() async {
    await DatabaseService.resetForTest();
    DatabaseService.setOverridePath(inMemoryDatabasePath);
    AppStateService.instance.setCurrentTab(0);
  });

  tearDown(() => DatabaseService.resetForTest());

  testWidgets('login: selección de usuario', (tester) async {
    tester.view.physicalSize = const Size(412, 892) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await _pumpGolden(tester, const LoginScreen(), 'login_select_user');
  });

  for (final user in [_anyel, _alexis]) {
    testWidgets('login: contraseña de ${user.name}', (tester) async {
      tester.view.physicalSize = const Size(412, 892) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_app(const LoginScreen()));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.tap(find.text(user.name).first);
      await _pumpGolden(
          tester, const LoginScreen(), 'login_password_${user.username}');
    });
  }

  for (final user in [_anyel, _alexis]) {
    testWidgets('mensajes vistos por ${user.name}', (tester) async {
      tester.view.physicalSize = const Size(412, 892) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.runAsync(() => _session(user));
      await _pumpGolden(
          tester, const MessagesScreen(), 'messages_${user.username}');
    });

    testWidgets('tareas vistas por ${user.name}', (tester) async {
      tester.view.physicalSize = const Size(412, 892) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.runAsync(() => _session(user));
      await _pumpGolden(tester, const TasksScreen(), 'tasks_${user.username}');
    });
  }

  testWidgets('ajustes (tema claro)', (tester) async {
    tester.view.physicalSize = const Size(412, 892) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.runAsync(() => _session(_anyel));
    await _pumpGolden(tester, const SettingsScreen(), 'settings_light',
        dark: false);
  });

  testWidgets('banners de conexión', (tester) async {
    tester.view.physicalSize = const Size(412, 120) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(const Column(children: [
      ConnectionBanner(state: AuthBannerState.online),
      SizedBox(height: 8),
      ConnectionBanner(state: AuthBannerState.sessionExpired),
    ])));
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('images/connection_banners.png'));
  });
}
