import 'dart:async';

import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/storage_service.dart';
import 'services/sync_service.dart';
import 'services/notification_service.dart';
import 'services/push_token_service.dart';
import 'utils/theme_controller.dart';
import 'widgets/splash_screen.dart';
import 'screens/login_screen.dart';
import 'widgets/layout_widget.dart';

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  GoogleFonts.config.allowRuntimeFetching = false;
  _initializeDatabaseFactory();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(MyRoot());
  unawaited(_initializeBackgroundServices());
  unawaited(_removeNativeSplashFallback());
}

Future<void> _initializeBackgroundServices() async {
  try {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (_) {}

  await _safeInitialize(NotificationService.instance.initialize);
  await _safeInitialize(PushTokenService.instance.initialize);
  SyncService.instance.startListening();
}

Future<void> _safeInitialize(Future<void> Function() initializer) async {
  try {
    await initializer().timeout(const Duration(seconds: 6));
  } catch (_) {}
}

Future<void> _removeNativeSplashFallback() async {
  await Future<void>.delayed(const Duration(seconds: 4));
  FlutterNativeSplash.remove();
}

void _initializeDatabaseFactory() {
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}

class MyRoot extends StatefulWidget {
  const MyRoot({super.key});

  @override
  State<MyRoot> createState() => _MyRootState();
}

class _MyRootState extends State<MyRoot> {
  final StorageService _storage = StorageService();
  late final ThemeController _controller;
  late final ThemeData _lightTheme;
  late final ThemeData _darkTheme;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = ThemeController(ThemeMode.dark);
    _initializeApp();

    _lightTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple, brightness: Brightness.light),
      textTheme: GoogleFonts.comicNeueTextTheme(),
      useMaterial3: true,
    ).copyWith(
      scaffoldBackgroundColor: const Color(0xFFF7F5FF),
      snackBarTheme: const SnackBarThemeData(
        contentTextStyle: TextStyle(color: Colors.white),
        actionTextColor: Colors.white,
      ),
    );

    _darkTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple, brightness: Brightness.dark),
      textTheme: GoogleFonts.comicNeueTextTheme(
          ThemeData(brightness: Brightness.dark).textTheme),
      useMaterial3: true,
    ).copyWith(
      scaffoldBackgroundColor: const Color(0xFF1C1E2A),
      snackBarTheme: const SnackBarThemeData(
        contentTextStyle: TextStyle(color: Colors.white),
        actionTextColor: Colors.white,
      ),
    );
  }

  Future<void> _initializeApp() async {
    final isDark = await _storage
        .getThemeMode()
        .timeout(const Duration(seconds: 3), onTimeout: () => null);
    final isLoggedIn = await _storage
        .isLoggedIn()
        .timeout(const Duration(seconds: 3), onTimeout: () => false);

    if (!mounted) return;
    setState(() {
      if (isDark != null) {
        _controller.setMode(isDark ? ThemeMode.dark : ThemeMode.light);
      }
      _isLoading = false;
    });

    if (isLoggedIn) {
      unawaited(
        PushTokenService.instance
            .syncTokenWithBackend()
            .timeout(const Duration(seconds: 6), onTimeout: () {}),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF1a1625),
          body: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      );
    }

    return ThemeProvider(
      controller: _controller,
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return MaterialApp(
            title: 'Anyel x Alexis',
            debugShowCheckedModeBanner: false,
            theme: _lightTheme,
            darkTheme: _darkTheme,
            themeMode: _controller.mode,
            home: const SplashScreen(),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/home': (context) => const LayoutWidget(),
            },
          );
        },
      ),
    );
  }
}
