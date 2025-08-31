import 'package:love_app/widgets/scattered_sparkles.dart';
import 'package:love_app/widgets/date_counter.dart';
import 'package:love_app/widgets/love_message.dart';
import 'package:love_app/widgets/love_animals.dart';
import 'package:love_app/widgets/header.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static final DateTime _startDate = DateTime(2024, 01, 27);

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        const Positioned.fill(child: ScatteredSparkles()),
        const Positioned(top: 0, left: 0, right: 0, child: Header()),
        Positioned(
          top: 100,
          child: Center(
            child: DateCounter(startDate: _startDate),
          ),
        ),
        const Positioned(
          top: 350,
          left: 0,
          right: 0,
          child: LoveMessage(),
        ),
        const Positioned(
          top: 550,
          left: 0,
          right: 0,
          child: LoveAnimals(),
        ),
      ],
    );
  }
}
