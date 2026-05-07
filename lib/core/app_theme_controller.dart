import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'services.dart';

class AppThemeController {
  AppThemeController._();

  static final AppThemeController instance = AppThemeController._();

  static const String _boxName = 'app_settings';
  static const String _themeKey = 'theme_mode';

  final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  Future<void> load() async {
    await ensureCoreHiveReady();
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }

    final stored = Hive.box(_boxName).get(_themeKey) as String?;
    themeMode.value = _themeModeFromString(stored);
  }

  Future<void> setDarkMode(bool enabled) async {
    await ensureCoreHiveReady();
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }

    final mode = enabled ? ThemeMode.dark : ThemeMode.light;
    themeMode.value = mode;
    await Hive.box(_boxName).put(_themeKey, _themeModeToString(mode));
  }

  Future<void> toggle() async {
    await setDarkMode(themeMode.value != ThemeMode.dark);
  }

  bool get isDarkMode => themeMode.value == ThemeMode.dark;

  ThemeMode _themeModeFromString(String? value) {
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.light;
    }
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.system:
        return 'light';
    }
  }
}
