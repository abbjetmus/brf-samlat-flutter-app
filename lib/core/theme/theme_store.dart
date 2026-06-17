import 'package:flutter/material.dart';
import 'package:flutter_compositions/flutter_compositions.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the app's theme mode (system/light/dark) and persists the choice.
class ThemeStore {
  static const String _key = 'app_theme_mode';

  final Ref<ThemeMode> themeMode;

  ThemeStore() : themeMode = Ref(ThemeMode.system);

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null) {
      themeMode.value = ThemeMode.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => ThemeMode.system,
      );
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}
