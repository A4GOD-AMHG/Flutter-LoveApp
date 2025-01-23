import 'dart:math';

import 'package:flutter/material.dart';
import 'package:love_app/utils/clippers.dart';

class Background extends StatelessWidget {
  final boxDecoration = BoxDecoration(
      gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.2, 0.8],
          colors: [Color(0xff2E305F), Color(0xFF292C3D)]));

  Background({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(decoration: boxDecoration),
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
