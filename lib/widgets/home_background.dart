import 'dart:math';

import 'package:love_app/utils/clippers.dart';
import 'package:flutter/material.dart';

class HomeBackground extends StatelessWidget {
  HomeBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: const [0.2, 0.8],
      colors: isDark
          ? const [Color(0xff2E305F), Color(0xFF1C1E2A)]
          : [
              Colors.white,
              const Color(0xFFEDE9FF),
            ],
    );

    return Stack(
      children: [
        Container(decoration: BoxDecoration(gradient: gradient)),
        if (isDark) ...[
          Positioned(top: 320, left: -100, child: _PurpleStar()),
          Positioned(
              top: 340,
              right: 70,
              child: _Sparkle(
                height: 50,
                width: 50,
              )),
          Positioned(
              top: 370,
              right: 10,
              child: _Sparkle(
                height: 80,
                width: 80,
              )),
          Positioned(
              top: 420,
              right: 70,
              child: _Sparkle(
                height: 50,
                width: 50,
              )),
        ],
      ],
    );
  }
}

class _PurpleStar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -pi / 5,
      child: CustomPaint(
        size: const Size(400, 400),
        painter: StartClipper(),
      ),
    );
  }
}

class _Sparkle extends StatelessWidget {
  final double width;
  final double height;

  const _Sparkle({required this.height, required this.width});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: SparklePainter(),
    );
  }
}
