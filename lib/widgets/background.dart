import 'package:flutter/material.dart';

class Background extends StatelessWidget {
  const Background({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? const [
              Color(0xFF1E0033),
              Color(0xFF4B0082),
              Color(0xFF7B1FA2),
            ]
          : const [
              Color(0xFFEDE9FF),
              Color(0xFFE5E0EC),
              Color(0xFFC4B0E6),
            ],
    );

    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
      ),
    );
  }
}
