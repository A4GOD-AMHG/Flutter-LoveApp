import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:love_app/widgets/layout_widget.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../services/storage_service.dart';
import '../screens/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final StorageService _storage = StorageService();
  bool _isLoggedIn = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        FlutterNativeSplash.remove();
      });
    });
  }

  Future<void> _checkAuth() async {
    bool isLoggedIn = false;
    try {
      isLoggedIn = await _storage
          .isLoggedIn()
          .timeout(const Duration(seconds: 3), onTimeout: () => false);
    } catch (_) {
      isLoggedIn = false;
    }

    if (!mounted) return;
    setState(() {
      _isLoggedIn = isLoggedIn;
      _isChecking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return Scaffold(
        backgroundColor: Colors.black45,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    return AnimatedSplashScreen(
      splash: const _SplashContent(),
      nextScreen: _isLoggedIn ? const LayoutWidget() : const LoginScreen(),
      duration: 1800,
      splashIconSize: 500,
      backgroundColor: Colors.black45,
    );
  }
}

class _SplashContent extends StatefulWidget {
  const _SplashContent();

  @override
  State<_SplashContent> createState() => _SplashContentState();
}

class _SplashContentState extends State<_SplashContent>
    with TickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Lottie.asset(
              'assets/lottie_animated_splash_screen.json',
              controller: _controller,
              repeat: true,
              animate: true,
              onLoaded: (composition) {
                _controller
                  ..duration = composition.duration
                  ..repeat();
              },
            ),
          ),
        ),
      ],
    );
  }
}
