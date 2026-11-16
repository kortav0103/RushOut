import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:rush_out/core/error/exceptions.dart';
import 'package:rush_out/data/datasources/local_database_datasource.dart';
import 'package:rush_out/data/models/daily_challenge_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('LocalDatabaseDataSource Tests (Mục 2.6)', () {
    test('throws CacheException instead of silently falling back to RAM when databaseFactory is unavailable', () async {
      final ds = LocalDatabaseDataSource(
        getDatabasesPathFn: () async => throw StateError('databaseFactory not initialized'),
      );

      await expectLater(
        ds.getAllLevelProgress(),
        throwsA(isA<CacheException>()),
      );
    });

    test('deduplicates concurrent openDatabase calls into a single SQLite initialization', () async {
      sqfliteFfiInit();
      int openCalls = 0;

      final ds = LocalDatabaseDataSource(
        getDatabasesPathFn: () async => inMemoryDatabasePath,
        openDatabaseFn: (
          path, {
          version,
          onCreate,
          onUpgrade,
        }) async {
          openCalls++;
          await Future<void>.delayed(const Duration(milliseconds: 25));
          return databaseFactoryFfi.openDatabase(
            path,
            options: OpenDatabaseOptions(
              version: version,
              onCreate: onCreate,
              onUpgrade: onUpgrade,
              singleInstance: false,
            ),
          );
        },
      );

      final results = await Future.wait([
        ds.getAllLevelProgress(),
        ds.getLevelProgress(1),
        ds.getCachedDailyChallenge('2026-11-16'),
      ]);

      expect(openCalls, 1);
      expect(results[0], isEmpty);
      expect(results[1], isNull);
      expect(results[2], isNull);
      await ds.close();
    });

    test('persists level progress and daily cache on disk via sqflite_common_ffi across instances', () async {
      sqfliteFfiInit();
      final tempDir = await Directory.systemTemp.createTemp('rush_out_db_test_');

      Future<Database> openFfiDb(
        String path, {
        int? version,
        OnDatabaseCreateFn? onCreate,
        OnDatabaseVersionChangeFn? onUpgrade,
      }) {
        return databaseFactoryFfi.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: version,
            onCreate: onCreate,
            onUpgrade: onUpgrade,
          ),
        );
      }

      try {
        final ds1 = LocalDatabaseDataSource(
          getDatabasesPathFn: () async => tempDir.path,
          openDatabaseFn: openFfiDb,
        );

        await ds1.upsertLevelProgress(
          levelId: 7,
          difficulty: 'easy',
          bestMoves: 6,
          stars: 3,
          isUnlocked: true,
        );
        await ds1.saveDailyChallengeCache(
          const DailyChallengeModel(
            dateKey: '2026-11-16',
            boardString: 'oooooo'
                'oooBoo'
                'AAoBoo'
                'oooooo'
                'oooooo'
                'oooooo',
            optimalMoves: 2,
            isCompleted: true,
            userMoves: 2,
            scoreSubmitted: true,
          ),
        );
        await ds1.close();

        // Re-open with a brand-new LocalDatabaseDataSource pointing to the same disk path
        final ds2 = LocalDatabaseDataSource(
          getDatabasesPathFn: () async => tempDir.path,
          openDatabaseFn: openFfiDb,
        );

        final progress = await ds2.getLevelProgress(7);
        expect(progress, isNotNull);
        expect(progress!['best_moves'], 6);
        expect(progress['stars'], 3);
        expect(progress['is_unlocked'], 1);

        final daily = await ds2.getCachedDailyChallenge('2026-11-16');
        expect(daily, isNotNull);
        expect(daily!.isCompleted, isTrue);
        expect(daily.userMoves, 2);
        expect(daily.scoreSubmitted, isTrue);

        await ds2.close();
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });
}
