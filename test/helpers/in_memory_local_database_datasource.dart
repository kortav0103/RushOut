import 'package:rush_out/data/datasources/local_database_datasource.dart';
import 'package:rush_out/data/models/daily_challenge_model.dart';

/// Test-only in-memory fake for [LocalDatabaseDataSource].
/// Keeps production code strictly backed by SQLite while allowing fast isolated unit tests.
class InMemoryLocalDatabaseDataSource extends LocalDatabaseDataSource {
  final Map<int, Map<String, dynamic>> _levelProgress = {};
  final Map<String, Map<String, dynamic>> _dailyCache = {};

  @override
  Future<Map<int, Map<String, dynamic>>> getAllLevelProgress() async {
    return {
      for (final entry in _levelProgress.entries)
        entry.key: Map<String, dynamic>.from(entry.value),
    };
  }

  @override
  Future<Map<String, dynamic>?> getLevelProgress(int levelId) async {
    final row = _levelProgress[levelId];
    return row != null ? Map<String, dynamic>.from(row) : null;
  }

  @override
  Future<void> upsertLevelProgress({
    required int levelId,
    required String difficulty,
    int? bestMoves,
    required int stars,
    required bool isUnlocked,
  }) async {
    _levelProgress[levelId] = {
      'level_id': levelId,
      'difficulty': difficulty,
      'best_moves': bestMoves,
      'stars': stars,
      'is_unlocked': isUnlocked ? 1 : 0,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  @override
  Future<DailyChallengeModel?> getCachedDailyChallenge(String dateKey) async {
    final row = _dailyCache[dateKey];
    return row != null ? DailyChallengeModel.fromCacheMap(row) : null;
  }

  @override
  Future<void> saveDailyChallengeCache(DailyChallengeModel challenge) async {
    _dailyCache[challenge.dateKey] = challenge.toCacheMap();
  }
}
