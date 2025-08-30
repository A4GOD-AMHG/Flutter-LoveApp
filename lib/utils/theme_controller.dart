import 'package:flutter/material.dart';

class ThemeController extends ChangeNotifier {
  ThemeMode _mode;
  ThemeController([this._mode = ThemeMode.system]);

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  void toggle() {
    if (_mode == ThemeMode.dark) {
      _mode = ThemeMode.light;
    } else {
      _mode = ThemeMode.dark;
    }
    notifyListeners();
  }

  void set(ThemeMode mode) {
    if (_mode != mode) {
      _mode = mode;
      notifyListeners();
    }
  }
}

class ThemeProvider extends InheritedNotifier<ThemeController> {
  const ThemeProvider(
      {super.key, required ThemeController controller, required Widget child})
      : super(notifier: controller, child: child);

  static ThemeController of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<ThemeProvider>();
    assert(provider != null, 'ThemeProvider not found in context');
    return provider!.notifier!;
  }
}
