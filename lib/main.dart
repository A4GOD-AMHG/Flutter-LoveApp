import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:love_app/utils/theme_controller.dart';
import 'package:love_app/widgets/splash_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  GoogleFonts.config.allowRuntimeFetching = false;

  runApp(MyRoot());
}

class MyRoot extends StatefulWidget {
  @override
  State<MyRoot> createState() => _MyRootState();
}

class _MyRootState extends State<MyRoot> {
  final ThemeController _controller = ThemeController(ThemeMode.dark);
  late final ThemeData _lightTheme;
  late final ThemeData _darkTheme;

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
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
          );
        },
      ),
    );
  }
}
