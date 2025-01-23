import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:love_app/screens/home_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedSplashScreen(
      splash: Column(
        children: [
          Expanded(
            child: Center(
              child: LottieBuilder.asset(
                  'assets/lottie_animated_splash_screen.json'),
            ),
          ),
        ],
      ),
      nextScreen: HomeScreen(),
      duration: 1000,
      splashIconSize: 500,
      backgroundColor: Colors.black45,
    );
  }
}
