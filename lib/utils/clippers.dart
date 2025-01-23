import 'dart:math';

import 'package:flutter/material.dart';

class HeartClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final Path path = Path();
    final double width = size.width;
    final double height = size.height;

    path.moveTo(width / 2, height / 5);
    path.cubicTo(5 * width / 14, 0, 0, height / 15, width / 28, 2 * height / 5);
    path.cubicTo(width / 14, 2 * height / 3, 3 * width / 7, 5 * height / 6,
        width / 2, height);
    path.cubicTo(4 * width / 7, 5 * height / 6, 13 * width / 14, 2 * height / 3,
        27 * width / 28, 2 * height / 5);
    path.cubicTo(width, height / 15, 9 * width / 14, 0, width / 2, height / 5);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class StartClipper extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Color(0xFFB14DDF),
          Color(0xFFA00FE2),
        ],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final Path path = Path();
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double radius = size.width / 2;

    for (int i = 0; i < 10; i++) {
      final double angle = i * pi / 5;
      final double r = i.isEven ? radius : radius / 2.5;
      final double x = cx + r * cos(angle);
      final double y = cy + r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class SparklePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Color(0xFFF7D700)
      ..style = PaintingStyle.fill;

    final Path path = Path();
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double outerRadius = size.width / 2;
    final double innerRadius = size.width / 5.5;

    for (int i = 0; i < 8; i++) {
      final double angle = i * pi / 4;
      final double r = i.isEven ? outerRadius : innerRadius;
      final double x = cx + r * cos(angle);
      final double y = cy + r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
