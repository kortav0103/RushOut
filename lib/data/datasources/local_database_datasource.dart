import 'dart:async';
import 'dart:math' as math;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../../core/error/exceptions.dart';
import '../models/daily_challenge_model.dart';

typedef DatabasesPathProvider = Future<String> Function();
typedef DatabaseOpener = Future<Database> Function(
  String path, {
  int? version,
  OnDatabaseCreateFn? onCreate,
  OnDatabaseVersionChangeFn? onUpgrade,
});

class LocalDatabaseDataSource {
  static const String _dbName = 'rush_out.db';
  static const int _dbVersion = 5;

  static const String tableLevelProgress = 'level_progress';
  static const String tableDailyCache = 'daily_cache';
  static const String tableAppWallet = 'app_wallet';
  static const String tableInProgressLevels = 'in_progress_levels';
  static const String hintBalanceKey = 'remaining_hints';

  final DatabasesPathProvider _getDatabasesPath;
  final DatabaseOpener _openDatabase;
  final String _dbFileName;

  Database? _database;
  Future<Database>? _openingDatabase;
  Future<void> _walletQueue = Future<void>.value();
  final Map<int, Future<void>> _inProgressQueues = {};

  LocalDatabaseDataSource({
    DatabasesPathProvider? getDatabasesPathFn,
    DatabaseOpener? openDatabaseFn,
    String dbFileName = _dbName,
  })  : _getDatabasesPath = getDatabasesPathFn ?? getDatabasesPath,
        _openDatabase = openDatabaseFn ?? openDatabase,
        _dbFileName = dbFileName;

  /// Returns the singleton SQLite [Database], memoizing concurrent open calls.
  Future<Database> get database {
    final existing = _database;
    if (existing != null && existing.isOpen) {
      return Future.value(existing);
    }

    final inFlight = _openingDatabase;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _openAndInitializeDatabase();
    _openingDatabase = future;
    return future.whenComplete(() {
      if (identical(_openingDatabase, future)) {
        _openingDatabase = null;
      }
    });
  }

  Future<Database> _openAndInitializeDatabase() async {
    try {
      final dbPath = await _getDatabasesPath();
      final fullPath =
          dbPath == inMemoryDatabasePath ? dbPath : p.join(dbPath, _dbFileName);
      final db = await _openDatabase(
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
              is_skipped INTEGER NOT NULL DEFAULT 0,
              updated_at TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE $tableDailyCache (
              date_key TEXT PRIMARY KEY,
              board_string TEXT NOT NULL,
              optimal_moves INTEGER NOT NULL,
              is_completed INTEGER NOT NULL DEFAULT 0,
              user_moves INTEGER,
              solved_board_string TEXT,
              best_move_history TEXT,
              score_submitted INTEGER NOT NULL DEFAULT 0,
              submitted_moves INTEGER,
              submitted_player_name TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE $tableAppWallet (
              wallet_key TEXT PRIMARY KEY,
              int_value INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE $tableInProgressLevels (
              level_id INTEGER PRIMARY KEY,
              board_string TEXT NOT NULL,
              move_count INTEGER NOT NULL,
              move_history TEXT NOT NULL,
              updated_at TEXT
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
          if (oldVersion < 3) {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS $tableAppWallet (
                wallet_key TEXT PRIMARY KEY,
                int_value INTEGER NOT NULL
              )
            ''');
          }
          if (oldVersion < 4) {
            await _addColumnIfMissing(
              db,
              table: tableLevelProgress,
              column: 'is_skipped',
              definition: 'INTEGER NOT NULL DEFAULT 0',
            );
            await db.execute('''
              CREATE TABLE IF NOT EXISTS $tableInProgressLevels (
                level_id INTEGER PRIMARY KEY,
                board_string TEXT NOT NULL,
                move_count INTEGER NOT NULL,
                move_history TEXT NOT NULL,
                updated_at TEXT
              )
            ''');
          }
          if (oldVersion < 5) {
            await _addColumnIfMissing(
              db,
              table: tableDailyCache,
              column: 'solved_board_string',
              definition: 'TEXT',
            );
            await _addColumnIfMissing(
              db,
              table: tableDailyCache,
              column: 'best_move_history',
              definition: 'TEXT',
            );
            await _addColumnIfMissing(
              db,
              table: tableDailyCache,
              column: 'submitted_moves',
              definition: 'INTEGER',
            );
            await _addColumnIfMissing(
              db,
              table: tableDailyCache,
              column: 'submitted_player_name',
              definition: 'TEXT',
            );
          }
        },
      );
      _database = db;
      return db;
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
    bool isSkipped = false,
  }) async {
    final data = <String, dynamic>{
      'level_id': levelId,
      'difficulty': difficulty,
      'best_moves': bestMoves,
      'stars': stars,
      'is_unlocked': isUnlocked ? 1 : 0,
      'is_skipped': isSkipped ? 1 : 0,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    final db = await database;
    try {
      await db.insert(
        tableLevelProgress,
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw CacheException('Failed to save progress for level $levelId: $e');
    }
  }

  Future<T> _enqueueInProgressOp<T>(int levelId, Future<T> Function() action) {
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

  Future<Map<String, dynamic>?> getInProgressLevel(int levelId) {
    return _enqueueInProgressOp(levelId, () async {
      final db = await database;
      try {
        final rows = await db.query(
          tableInProgressLevels,
          where: 'level_id = ?',
          whereArgs: [levelId],
          limit: 1,
        );
        if (rows.isEmpty) return null;
        return Map<String, dynamic>.from(rows.first);
      } catch (e) {
        throw CacheException(
          'Failed to read in-progress state for level $levelId: $e',
        );
      }
    });
  }

  Future<void> saveInProgressLevel({
    required int levelId,
    required String boardString,
    required int moveCount,
    required String moveHistoryJson,
  }) {
    return _enqueueInProgressOp(levelId, () async {
      final db = await database;
      try {
        await db.insert(
          tableInProgressLevels,
          {
            'level_id': levelId,
            'board_string': boardString,
            'move_count': moveCount,
            'move_history': moveHistoryJson,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (e) {
        throw CacheException(
          'Failed to save in-progress state for level $levelId: $e',
        );
      }
    });
  }

  Future<void> clearInProgressLevel(int levelId) {
    return _enqueueInProgressOp(levelId, () async {
      final db = await database;
      try {
        await db.delete(
          tableInProgressLevels,
          where: 'level_id = ?',
          whereArgs: [levelId],
        );
      } catch (e) {
        throw CacheException(
          'Failed to clear in-progress state for level $levelId: $e',
        );
      }
    });
  }

  Future<DailyChallengeModel?> getCachedDailyChallenge(String dateKey) async {
    final db = await database;
    try {
      final rows = await db.query(
        tableDailyCache,
        where: 'date_key = ?',
        whereArgs: [dateKey],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return DailyChallengeModel.fromCacheMap(rows.first);
    } on CacheException {
      rethrow;
    } catch (e) {
      throw CacheException('Failed to read cached daily challenge: $e');
    }
  }

  Future<void> saveDailyChallengeCache(DailyChallengeModel challenge) async {
    final map = challenge.toCacheMap();
    final db = await database;
    try {
      await db.insert(
        tableDailyCache,
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw CacheException('Failed to cache daily challenge: $e');
    }
  }

  Future<int?> getWalletValue(String key) async {
    final db = await database;
    try {
      final rows = await db.query(
        tableAppWallet,
        where: 'wallet_key = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return rows.first['int_value'] as int?;
    } catch (e) {
      throw CacheException('Failed to read wallet value for $key: $e');
    }
  }

  Future<void> setWalletValue(String key, int value) async {
    final db = await database;
    try {
      await db.insert(
        tableAppWallet,
        {'wallet_key': key, 'int_value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw CacheException('Failed to save wallet value for $key: $e');
    }
  }

  Future<T> _enqueueWalletOp<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _walletQueue = _walletQueue.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<int> adjustWalletValue(
    String key, {
    required int defaultValue,
    required int delta,
    int minValue = 0,
  }) {
    return _enqueueWalletOp(() async {
      final current = await getWalletValue(key) ?? defaultValue;
      final next = math.max(minValue, current + delta);
      await setWalletValue(key, next);
      return next;
    });
  }

  Future<void> close() async {
    final db = _database;
    _database = null;
    if (db != null && db.isOpen) {
      await db.close();
    }
  }
}
