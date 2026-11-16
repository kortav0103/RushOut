import 'package:shared_preferences/shared_preferences.dart';

class TutorialService {
  static const String hasCompletedTutorialKey =
      'rush_out_has_completed_tutorial';

  final Future<SharedPreferences> Function()? _prefsProvider;
  bool _memoryFallback = false;

  TutorialService({
    Future<SharedPreferences> Function()? prefsProvider,
  }) : _prefsProvider = prefsProvider;

  Future<bool> hasCompletedTutorial() async {
    try {
      final prefs = await (_prefsProvider?.call() ??
          SharedPreferences.getInstance());
      return prefs.getBool(hasCompletedTutorialKey) ?? false;
    } catch (_) {
      return _memoryFallback;
    }
  }

  Future<void> setTutorialCompleted([bool completed = true]) async {
    _memoryFallback = completed;
    try {
      final prefs = await (_prefsProvider?.call() ??
          SharedPreferences.getInstance());
      await prefs.setBool(hasCompletedTutorialKey, completed);
    } catch (_) {
      // Fallback already updated in memory
    }
  }
}
