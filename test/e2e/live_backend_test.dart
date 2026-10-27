// Flujo real de la app contra un backend en vivo: HTTP, WebSocket y SQLite
// reales; solo se simulan los plugins nativos (conectividad y notificaciones).
// Guarda una captura por paso en test/e2e/screenshots/.
//
//   (backend) DB_PATH=/tmp/loveapp-e2e.db SERVER_PORT=4418 go run .
//   flutter test test/e2e --dart-define=LIVE_API=http://127.0.0.1:4418/
//
// Sin LIVE_API el test se omite para que `flutter test` no dependa de la red.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:love_app/screens/login_screen.dart';
import 'package:love_app/services/database_service.dart';
import 'package:love_app/utils/theme_controller.dart';
import 'package:love_app/widgets/layout_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const api = String.fromEnvironment('LIVE_API');
final shownNotifications = <Map<Object?, Object?>>[];

Future<void> realWait(WidgetTester tester, [int ms = 100]) async {
  await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> settle(WidgetTester tester, [int ms = 1200]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await realWait(tester);
  }
}

Future<void> waitFor(WidgetTester tester, Finder finder,
    {int seconds = 15}) async {
  for (var i = 0; i < seconds * 10; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await realWait(tester);
  }
  throw TestFailure('No apareció: $finder');
}

Future<void> shot(WidgetTester tester, String name) async {
  await tester.pump(const Duration(milliseconds: 50));
  final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('screen')));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('test/e2e/screenshots/$name.png');
    await file.create(recursive: true);
    await file.writeAsBytes(png!.buffer.asUint8List());
  });
}

/// El otro integrante usa la API directamente, como si fuera su teléfono.
Future<String> apiLogin(String user, String pass) async {
  final res = await http.post(Uri.parse('${api}auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': user, 'password': pass}));
  return (jsonDecode(res.body) as Map)['token'] as String;
}

Future<void> apiSend(String token, String text) => http.post(
      Uri.parse('${api}messages'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
      body: jsonEncode({'content': text}),
    );

Widget app() => ThemeProvider(
      controller: ThemeController(ThemeMode.dark),
      child: RepaintBoundary(
        key: const ValueKey('screen'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.deepPurple, brightness: Brightness.dark),
            fontFamily: 'ComicNeue',
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFF1C1E2A),
          ),
          home: const LoginScreen(),
          routes: {
            '/login': (_) => const LoginScreen(),
            '/home': (_) => const LayoutWidget(),
          },
        ),
      ),
    );

Future<void> loginAs(WidgetTester tester, String name, String password) async {
  await waitFor(tester, find.text(name));
  await settle(tester, 600);
  await shot(tester, '${name.toLowerCase()}_01_login');
  await tester.tap(find.text(name).first);
  await settle(tester, 800);
  await tester.enterText(find.byType(TextField), password);
  await shot(tester, '${name.toLowerCase()}_02_password');
  await tester.tap(find.text('Entrar'));
  await waitFor(tester, find.text('Mensajes'));
  await settle(tester, 1500);
  await shot(tester, '${name.toLowerCase()}_03_home');
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await settle(tester, 1500);
}

Future<void> logout(WidgetTester tester) async {
  await openTab(tester, 'Opciones');
  await tester.tap(find.text('Cerrar Sesión').first);
  await settle(tester, 600);
  await tester.tap(find.widgetWithText(ElevatedButton, 'Cerrar Sesión'));
  await settle(tester, 1500);
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    final dbFile = '${Directory.systemTemp.path}/love_app_e2e.db';
    if (File(dbFile).existsSync()) File(dbFile).deleteSync();
    DatabaseService.setOverridePath(dbFile);

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/connectivity'),
        (_) async => ['wifi']);
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    messenger.setMockMethodCallHandler(
        const MethodChannel('dexterous.com/flutter/local_notifications'),
        (call) async {
      if (call.method == 'show') {
        shownNotifications.add(call.arguments as Map<Object?, Object?>);
      }
      return call.method == 'initialize' ? true : null;
    });

    final font = FontLoader('ComicNeue')
      ..addFont(rootBundle.load('assets/google_fonts/ComicNeue-Regular.ttf'))
      ..addFont(rootBundle.load('assets/google_fonts/ComicNeue-Bold.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  testWidgets('Anyel y Alexis contra el backend real', (tester) async {
    HttpOverrides.global =
        null; // el binding de tests bloquea la red por defecto
    tester.view.physicalSize = const Size(412, 892) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'server_host': api,
      // ChatRealtimeService redirige localhost/127.0.0.1 a producción,
      // así que el WebSocket local se alcanza por otra IP de loopback.
      'server_ws':
          '${api.replaceFirst('http', 'ws').replaceFirst('127.0.0.1', '127.0.0.2')}ws',
    });
    final stamp = DateTime.now().millisecondsSinceEpoch % 100000;

    await tester.pumpWidget(app());

    // --- Anyel ---
    await loginAs(tester, 'Anyel', 'anyel');
    await openTab(tester, 'Mensajes');
    await tester.enterText(find.byType(TextField).last, 'Hola Alexis #$stamp');
    await tester.tap(find.byIcon(Icons.send));
    await waitFor(tester, find.text('Hola Alexis #$stamp'));
    await settle(tester);
    await shot(tester, 'anyel_04_message_sent');

    final alexisToken =
        await tester.runAsync(() => apiLogin('alexis', 'alexis'));
    await tester.runAsync(() => apiSend(alexisToken!, 'Hola Anyel! #$stamp'));
    await waitFor(tester, find.text('Hola Anyel! #$stamp'));
    await settle(tester);
    await shot(tester, 'anyel_05_message_received_live');

    // Estando en otra pestaña: notificación local + badge de no leídos.
    await openTab(tester, 'Tareas');
    await tester.runAsync(() => apiSend(alexisToken!, '¿Cenamos hoy? #$stamp'));
    await settle(tester, 2500);
    await shot(tester, 'anyel_06_unread_badge');
    expect(
      shownNotifications.any((n) =>
          n['title'] == 'Alexis' && n['body'] == '¿Cenamos hoy? #$stamp'),
      isTrue,
      reason: 'debe mostrarse una notificación local del mensaje de Alexis',
    );

    await tester.tap(find.text('Nueva'));
    await settle(tester, 600);
    await tester.enterText(
        find.widgetWithText(TextField, 'Título'), 'Reservar cena #$stamp');
    await tester.tap(find.text('Crear'));
    await waitFor(tester, find.text('Reservar cena #$stamp'));
    await settle(tester);
    await shot(tester, 'anyel_07_task_created');

    await logout(tester);

    // --- Alexis ---
    await loginAs(tester, 'Alexis', 'alexis');
    await openTab(tester, 'Mensajes');
    await waitFor(tester, find.text('Hola Alexis #$stamp'));
    await settle(tester);
    await shot(tester, 'alexis_04_conversation');

    await openTab(tester, 'Tareas');
    await waitFor(tester, find.text('Reservar cena #$stamp'));
    await shot(tester, 'alexis_05_tasks');

    await openTab(tester, 'Opciones');
    await shot(tester, 'alexis_06_settings');
    await logout(tester);
    await waitFor(tester, find.text('Anyel'));
    await shot(tester, 'logout');
  }, skip: api.isEmpty, timeout: const Timeout(Duration(minutes: 3)));
}
