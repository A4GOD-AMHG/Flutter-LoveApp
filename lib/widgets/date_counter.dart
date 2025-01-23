import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:love_app/utils/clippers.dart';

class DateCounter extends StatelessWidget {
  final DateTime startDate;

  const DateCounter({super.key, required this.startDate});

  String _calculateDifference() {
    final now = DateTime.now();
    final diff = now.difference(startDate).inDays;
    String differenceDays = diff == 1 ? '$diff día' : '$diff días';
    return differenceDays;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipPath(
            clipper: HeartClipper(),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 283, minWidth: 283),
              height: 203,
              decoration: BoxDecoration(
                color: Color(0xffA00FE2),
                border: Border.all(
                  color: Color(0xffA00FE2),
                  width: 1.5,
                ),
              ),
            ),
          ),
          ClipPath(
            clipper: HeartClipper(),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 280, minWidth: 280),
              height: 200,
              color: Color(0xFF2E305F),
              child: Stack(
                children: [
                  ClipRect(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Transform.translate(
                        offset: const Offset(0, -190),
                        child: Container(
                          constraints: const BoxConstraints(
                              maxWidth: 283, minWidth: 283),
                          width: double.infinity,
                          height: 300,
                          child: LottieBuilder.asset(
                            'assets/drop_purple_water.json',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: Color(0xffA00FE2),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 70),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Text(
                        _calculateDifference(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
