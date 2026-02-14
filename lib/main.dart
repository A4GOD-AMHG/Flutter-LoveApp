import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'services/storage_service.dart';
import 'utils/theme_controller.dart';
import 'widgets/splash_screen.dart';
import 'screens/login_screen.dart';
import 'widgets/layout_widget.dart';

void main() {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  GoogleFonts.config.allowRuntimeFetching = false;

  runApp(MyRoot());
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
    );

    _darkTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple, brightness: Brightness.dark),
      textTheme: GoogleFonts.comicNeueTextTheme(
          ThemeData(brightness: Brightness.dark).textTheme),
      useMaterial3: true,
    ).copyWith(
      scaffoldBackgroundColor: const Color(0xFF1C1E2A),
    );
  }

  Future<void> _initializeApp() async {
    final isDark = await _storage.getThemeMode();

    setState(() {
      if (isDark != null) {
        _controller.setMode(isDark ? ThemeMode.dark : ThemeMode.light);
      }
      _isLoading = false;
    });
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
