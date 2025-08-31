import 'package:flutter/material.dart';

class LoveAnimals extends StatelessWidget {
  const LoveAnimals({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2E305F) : Colors.green.shade50,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: isDark ? Colors.green.shade300 : Colors.green.shade400,
                width: 2,
              ),
            ),
            child: Image.asset(
              'assets/frog.png',
              width: 75,
              height: 75,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 20),
          Column(
            children: [
              Text('💕', style: TextStyle(fontSize: 20)),
              const SizedBox(height: 5),
              Text('💖', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 5),
              Text('💕', style: TextStyle(fontSize: 12)),
            ],
          ),
          const SizedBox(width: 20),
          Container(
            padding: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2E305F) : Colors.yellow.shade50,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: isDark ? Colors.yellow.shade300 : Colors.yellow.shade600,
                width: 2,
              ),
            ),
            child: Image.asset(
              'assets/duck.png',
              width: 75,
              height: 75,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}
