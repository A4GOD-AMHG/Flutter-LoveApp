import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:love_app/widgets/layout_widget.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedSplashScreen(
      splash: const _SplashContent(),
      nextScreen: const LayoutWidget(),
      duration: 2500,
      splashIconSize: 500,
      backgroundColor: isDark ? Colors.black45 : Colors.white,
    );
  }
}

class _SplashContent extends StatelessWidget {
  const _SplashContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: LottieBuilder.asset(
              'assets/lottie_animated_splash_screen.json',
              repeat: false,
            ),
          ),
        ),
      ],
    );
  }
}
