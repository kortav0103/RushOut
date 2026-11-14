import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/score_model.dart';

class LocalDatabaseDataSource {
  static const String _dbName = 'rush_out.db';
  static const int _dbVersion = 1;

  static const String tableLevelProgress = 'level_progress';
  static const String tableDailyCache = 'daily_cache';

  Database? _database;

  // Fallback in-memory storage if SQLite is unavailable on desktop/test environment
  final Map<int, Map<String, dynamic>> _memoryLevelProgress = {};
  final Map<String, Map<String, dynamic>> _memoryDailyCache = {};

  Future<Database?> get database async {
    if (_database != null) return _database;
    try {
      final dbPath = await getDatabasesPath();
      final fullPath = p.join(dbPath, _dbName);
      _database = await openDatabase(
        fullPath,
        version: _dbVersion,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE $tableLevelProgress (
              level_id INTEGER PRIMARY KEY,
              difficulty TEXT,
              best_moves INTEGER,
              stars INTEGER,
              is_unlocked INTEGER
            )
          ''');
          await db.execute('''
            CREATE TABLE $tableDailyCache (
              date_key TEXT PRIMARY KEY,
              board_string TEXT,
              optimal_moves INTEGER,
              is_completed INTEGER,
              user_moves INTEGER
            )
          ''');
        },
      );
      return _database;
    } catch (_) {
      return null;
    }
  }

  Future<Map<int, Map<String, dynamic>>> getAllLevelProgress() async {
    final db = await database;
    if (db == null) {
      return Map<int, Map<String, dynamic>>.from(_memoryLevelProgress);
    }
    try {
      final rows = await db.query(tableLevelProgress);
      final Map<int, Map<String, dynamic>> result = {};
      for (final row in rows) {
        final id = row['level_id'] as int?;
        if (id != null) {
          result[id] = Map<String, dynamic>.from(row);
        }
      }
      return result;
    } catch (_) {
      return Map<int, Map<String, dynamic>>.from(_memoryLevelProgress);
    }
  }

  Future<Map<String, dynamic>?> getLevelProgress(int levelId) async {
    final db = await database;
    if (db == null) {
      return _memoryLevelProgress[levelId];
    }
    try {
      final rows = await db.query(
        tableLevelProgress,
        where: 'level_id = ?',
        whereArgs: [levelId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return Map<String, dynamic>.from(rows.first);
    } catch (_) {
      return _memoryLevelProgress[levelId];
    }
  }

  Future<void> upsertLevelProgress({
    required int levelId,
    required String difficulty,
    int? bestMoves,
    required int stars,
    required bool isUnlocked,
  }) async {
    final data = <String, dynamic>{
      'level_id': levelId,
      'difficulty': difficulty,
      'best_moves': bestMoves,
      'stars': stars,
      'is_unlocked': isUnlocked ? 1 : 0,
    };
    _memoryLevelProgress[levelId] = data;

    final db = await database;
    if (db == null) return;
    try {
      await db.insert(
        tableLevelProgress,
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  Future<DailyChallengeModel?> getCachedDailyChallenge(String dateKey) async {
    final db = await database;
    if (db == null) {
      final mem = _memoryDailyCache[dateKey];
      return mem != null ? DailyChallengeModel.fromCacheMap(mem) : null;
    }
    try {
      final rows = await db.query(
        tableDailyCache,
        where: 'date_key = ?',
        whereArgs: [dateKey],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return DailyChallengeModel.fromCacheMap(rows.first);
    } catch (_) {
      final mem = _memoryDailyCache[dateKey];
      return mem != null ? DailyChallengeModel.fromCacheMap(mem) : null;
    }
  }

  Future<void> saveDailyChallengeCache(DailyChallengeModel challenge) async {
    final map = challenge.toCacheMap();
    _memoryDailyCache[challenge.dateKey] = map;

    final db = await database;
    if (db == null) return;
    try {
      await db.insert(
        tableDailyCache,
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }
}
