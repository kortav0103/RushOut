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
  static const int _dbVersion = 2;

  static const String tableLevelProgress = 'level_progress';
  static const String tableDailyCache = 'daily_cache';

  final DatabasesPathProvider _getDatabasesPath;
  final DatabaseOpener _openDatabase;
  final String _dbFileName;

  Database? _database;
  Future<Database>? _openingDatabase;

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

  Future<void> close() async {
    final db = _database;
    _database = null;
    if (db != null && db.isOpen) {
      await db.close();
    }
  }
}
