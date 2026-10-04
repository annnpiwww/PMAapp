import 'package:flutter/material.dart';
import '../../data/services/storage_service.dart';

class ThemeService {
  ThemeService._();
  static final ThemeService instance = ThemeService._();

  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  static void init() {
    final savedMode = StorageService.getThemeMode();
    switch (savedMode) {
      case 'light':
        themeModeNotifier.value = ThemeMode.light;
        break;
      case 'dark':
        themeModeNotifier.value = ThemeMode.dark;
        break;
      default:
        themeModeNotifier.value = ThemeMode.system;
        break;
    }
  }

  static bool isDarkMode(BuildContext context) {
    if (themeModeNotifier.value == ThemeMode.dark) return true;
    if (themeModeNotifier.value == ThemeMode.light) return false;
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }

  static Future<void> toggleTheme(BuildContext context) async {
    final currentlyDark = isDarkMode(context);
    final newMode = currentlyDark ? ThemeMode.light : ThemeMode.dark;
    themeModeNotifier.value = newMode;
    await StorageService.saveThemeMode(currentlyDark ? 'light' : 'dark');
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    String modeStr = 'system';
    if (mode == ThemeMode.light) modeStr = 'light';
    if (mode == ThemeMode.dark) modeStr = 'dark';
    await StorageService.saveThemeMode(modeStr);
  }
}
