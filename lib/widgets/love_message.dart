import 'package:google_fonts/google_fonts.dart';
import 'package:love_app/utils/clippers.dart';
import 'package:flutter/material.dart';
import 'dart:math';

class LoveMessage extends StatelessWidget {
  const LoveMessage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            top: -10,
            left: 10,
            child: _BackgroundStar(),
          ),
          const Positioned(
            top: 80,
            right: 30,
            child: _Sparkle(size: 35),
          ),
          const Positioned(
            top: 50,
            right: 70,
            child: _Sparkle(size: 30),
          ),
          const Positioned(
            bottom: -20,
            left: 60,
            child: _Sparkle(size: 30),
          ),
          Center(
            child: _GlassText(isDark: isDark),
          ),
        ],
      ),
    );
  }
}

class _BackgroundStar extends StatelessWidget {
  const _BackgroundStar();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: pi / 6,
      child: CustomPaint(
        size: const Size(180, 180),
        painter: StartClipper(),
      ),
    );
  }
}

class _Sparkle extends StatelessWidget {
  final double size;

  const _Sparkle({required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: SparklePainter(),
    );
  }
}

class _GlassText extends StatelessWidget {
  final bool isDark;

  const _GlassText({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.05,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.6))
              .withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.1),
            width: 1.2,
          ),
        ),
        child: Text(
          "De aquí hasta a la luna\n"
          "a paso de ranita enferma coja\n"
          "que carga un pollito enfermo",
          textAlign: TextAlign.center,
          style: GoogleFonts.comicNeue(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}
