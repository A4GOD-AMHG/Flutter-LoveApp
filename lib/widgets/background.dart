import 'package:flutter/material.dart';

class Background extends StatefulWidget {
  const Background({super.key});

  @override
  State<Background> createState() => _BackgroundState();
}

class _BackgroundState extends State<Background> {
  late LinearGradient _lightGradient;
  late LinearGradient _darkGradient;

  @override
  void initState() {
    super.initState();
    _lightGradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFEDE9FF),
        Color(0xFFE5E0EC),
        Color(0xFFC4B0E6),
      ],
    );

    _darkGradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF1E0033),
        Color(0xFF4B0082),
        Color(0xFF7B1FA2),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: isDark ? _darkGradient : _lightGradient,
      ),
    );
  }
}
