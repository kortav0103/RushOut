import 'dart:async';
import 'package:rush_out/data/datasources/local_database_datasource.dart';
import 'package:rush_out/data/models/daily_challenge_model.dart';

/// Test-only in-memory fake for [LocalDatabaseDataSource].
/// Keeps production code strictly backed by SQLite while allowing fast isolated unit tests.
class InMemoryLocalDatabaseDataSource extends LocalDatabaseDataSource {
  final Map<int, Map<String, dynamic>> _levelProgress = {};
  final Map<int, Map<String, dynamic>> _inProgressLevels = {};
  final Map<int, Future<void>> _inProgressQueues = {};
  final Map<String, Map<String, dynamic>> _dailyCache = {};
  final Map<String, int> _wallet = {};

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
    bool isSkipped = false,
  }) async {
    _levelProgress[levelId] = {
      'level_id': levelId,
      'difficulty': difficulty,
      'best_moves': bestMoves,
      'stars': stars,
      'is_unlocked': isUnlocked ? 1 : 0,
      'is_skipped': isSkipped ? 1 : 0,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Future<T> _enqueue<T>(int levelId, Future<T> Function() action) {
    final prev = _inProgressQueues[levelId] ?? Future<void>.value();
    final completer = Completer<T>();
    final next = prev.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    _inProgressQueues[levelId] = next.whenComplete(() {
      if (identical(_inProgressQueues[levelId], next)) {
        _inProgressQueues.remove(levelId);
      }
    });
    return completer.future;
  }

  @override
  Future<Map<String, dynamic>?> getInProgressLevel(int levelId) {
    return _enqueue(levelId, () async {
      final row = _inProgressLevels[levelId];
      return row != null ? Map<String, dynamic>.from(row) : null;
    });
  }

  @override
  Future<void> saveInProgressLevel({
    required int levelId,
    required String boardString,
    required int moveCount,
    required String moveHistoryJson,
  }) {
    return _enqueue(levelId, () async {
      _inProgressLevels[levelId] = {
        'level_id': levelId,
        'board_string': boardString,
        'move_count': moveCount,
        'move_history': moveHistoryJson,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
    });
  }

  @override
  Future<void> clearInProgressLevel(int levelId) {
    return _enqueue(levelId, () async {
      _inProgressLevels.remove(levelId);
    });
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

  @override
  Future<int?> getWalletValue(String key) async => _wallet[key];

  @override
  Future<void> setWalletValue(String key, int value) async {
    _wallet[key] = value;
  }
}
