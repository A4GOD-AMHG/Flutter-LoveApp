import 'package:love_app/utils/theme_controller.dart';
import 'package:flutter/material.dart';

abstract class ThemeAwareWidget extends StatelessWidget {
  const ThemeAwareWidget({super.key});

  Widget buildWithTheme(
      BuildContext context, bool isDark, ThemeController themeController);

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final themeController = ThemeProvider.of(context);
        return buildWithTheme(context, isDark, themeController);
      },
    );
  }
}

class ThemeListener extends StatefulWidget {
  final Widget Function(
      BuildContext context, bool isDark, ThemeController controller) builder;

  const ThemeListener({super.key, required this.builder});

  @override
  State<ThemeListener> createState() => _ThemeListenerState();
}

class _ThemeListenerState extends State<ThemeListener> {
  late ThemeController _controller;
  late bool _isDark;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newController = ThemeProvider.of(context);
    final newIsDark = Theme.of(context).brightness == Brightness.dark;

    if (_controller != newController) {
      _controller.removeListener(_onThemeChanged);
      _controller = newController;
      _controller.addListener(_onThemeChanged);
    }

    if (_isDark != newIsDark) {
      _isDark = newIsDark;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller = ThemeProvider.of(context);
      _isDark = Theme.of(context).brightness == Brightness.dark;
      _controller.addListener(_onThemeChanged);
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) {
      final newIsDark = Theme.of(context).brightness == Brightness.dark;
      if (_isDark != newIsDark) {
        setState(() {
          _isDark = newIsDark;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _isDark, _controller);
  }
}
