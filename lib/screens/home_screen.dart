import 'package:flutter/material.dart';
import 'package:love_app/widgets/background.dart';
import 'package:love_app/widgets/date_counter.dart';
import 'package:love_app/widgets/header.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Background(),
          Positioned(
            top: 0,
            child: Header(),
          ),
          Positioned(
            top: 100,
            child: Center(
              child: DateCounter(
                startDate: DateTime(2024, 01, 27),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
