import 'package:love_app/utils/clippers.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';

class DateCounter extends StatefulWidget {
  final DateTime startDate;

  const DateCounter({super.key, required this.startDate});

  @override
  State<DateCounter> createState() => _DateCounterState();
}

class _DateCounterState extends State<DateCounter> {
  late String _daysDifference;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _updateDifference();
    _scheduleNextUpdate();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateDifference() {
    final now = DateTime.now();
    final diff = now.difference(widget.startDate).inDays;
    _daysDifference = diff == 1 ? '$diff día' : '$diff días';
  }

  void _scheduleNextUpdate() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final timeUntilMidnight = tomorrow.difference(now);

    _timer = Timer(timeUntilMidnight, () {
      if (mounted) {
        setState(() {
          _updateDifference();
        });
        _scheduleNextUpdate();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final outerColor = const Color(0xffA00FE2);
    final innerColor = const Color(0xFFF3ECFF);
    final fillBarColor = const Color(0xffA00FE2);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipPath(
            clipper: HeartClipper(),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 283, minWidth: 283),
              height: 202,
              decoration: BoxDecoration(
                color: outerColor,
                border: Border.all(
                  color: outerColor,
                  width: 1,
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
              color: innerColor,
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
                            repeat: true,
                            animate: true,
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
                      height: 110,
                      decoration: BoxDecoration(
                        color: fillBarColor,
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
                        _daysDifference,
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
