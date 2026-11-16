import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../../core/error/exceptions.dart';
import '../models/daily_challenge_model.dart';

class LocalDatabaseDataSource {
  static const String _dbName = 'rush_out.db';
  static const int _dbVersion = 2;

  static const String tableLevelProgress = 'level_progress';
  static const String tableDailyCache = 'daily_cache';

  Database? _database;

  // Fallback in-memory storage only when SQLite plugin is unavailable (e.g. unit tests)
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
              is_unlocked INTEGER,
              updated_at TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE $tableDailyCache (
              date_key TEXT PRIMARY KEY,
              board_string TEXT,
              optimal_moves INTEGER,
              is_completed INTEGER,
              user_moves INTEGER,
              score_submitted INTEGER NOT NULL DEFAULT 0
            )
          ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await _addColumnIfMissing(
              db,
              table: tableLevelProgress,
              column: 'updated_at',
              definition: 'TEXT',
            );
            await _addColumnIfMissing(
              db,
              table: tableDailyCache,
              column: 'score_submitted',
              definition: 'INTEGER NOT NULL DEFAULT 0',
            );
          }
        },
      );
      return _database;
    } on MissingPluginException {
      return null;
    } on UnimplementedError {
      return null;
    } on StateError catch (e) {
      if (e.message.contains('databaseFactory')) {
        return null;
      }
      throw CacheException('Failed to open local database: $e');
    } catch (e) {
      throw CacheException('Failed to open local database: $e');
    }
  }

  static Future<void> _addColumnIfMissing(
    Database db, {
    required String table,
    required String column,
    required String definition,
  }) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
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
    } catch (e) {
      throw CacheException('Failed to read level progress: $e');
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
    } catch (e) {
      throw CacheException('Failed to read progress for level $levelId: $e');
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
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    final db = await database;
    if (db == null) {
      _memoryLevelProgress[levelId] = data;
      return;
    }
    try {
      await db.insert(
        tableLevelProgress,
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _memoryLevelProgress[levelId] = data;
    } catch (e) {
      throw CacheException('Failed to save progress for level $levelId: $e');
    }
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
    } catch (e) {
      throw CacheException('Failed to read cached daily challenge: $e');
    }
  }

  Future<void> saveDailyChallengeCache(DailyChallengeModel challenge) async {
    final map = challenge.toCacheMap();

    final db = await database;
    if (db == null) {
      _memoryDailyCache[challenge.dateKey] = map;
      return;
    }
    try {
      await db.insert(
        tableDailyCache,
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _memoryDailyCache[challenge.dateKey] = map;
    } catch (e) {
      throw CacheException('Failed to cache daily challenge: $e');
    }
  }
}
