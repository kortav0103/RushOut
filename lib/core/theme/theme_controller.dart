import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

const _themeStorageKey = 'readzen_theme_mode';

/// SharedPreferences instance overridden during app initialization or testing.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden at startup',
  );
});

/// Manages the active application theme and persists user choice locally.
class ThemeController extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final stored = prefs.getString(_themeStorageKey);
    return AppThemeMode.fromStorageKey(stored);
  }

  Future<void> setTheme(AppThemeMode mode) async {
    state = mode;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_themeStorageKey, mode.storageKey);
  }
}

final themeControllerProvider =
    NotifierProvider<ThemeController, AppThemeMode>(ThemeController.new);
