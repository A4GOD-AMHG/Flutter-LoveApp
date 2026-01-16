import 'package:love_app/utils/clippers.dart';
import 'package:flutter/material.dart';

class ScatteredSparkles extends StatelessWidget {
  const ScatteredSparkles({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;

        return Stack(
          children: [
            Positioned(
              top: 120,
              right: 40,
              child: CustomPaint(
                size: const Size(35, 35),
                painter: SparklePainter(),
              ),
            ),
            Positioned(
              top: 280,
              left: 20,
              child: CustomPaint(
                size: const Size(30, 30),
                painter: SparklePainter(),
              ),
            ),
            Positioned(
              top: 580,
              left: 50,
              child: CustomPaint(
                size: const Size(22, 22),
                painter: SparklePainter(),
              ),
            ),
            Positioned(
              top: 620,
              right: screenWidth * 0.3,
              child: CustomPaint(
                size: const Size(32, 32),
                painter: SparklePainter(),
              ),
            ),
            Positioned(
              top: 680,
              left: screenWidth * 0.2,
              child: CustomPaint(
                size: const Size(26, 26),
                painter: SparklePainter(),
              ),
            ),
            Positioned(
              top: 720,
              right: 20,
              child: CustomPaint(
                size: const Size(24, 24),
                painter: SparklePainter(),
              ),
            ),
          ],
        );
      },
    );
  }
}
