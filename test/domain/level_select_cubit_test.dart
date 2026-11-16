import 'package:flutter_test/flutter_test.dart';
import 'package:rush_out/data/datasources/level_asset_datasource.dart';
import 'package:rush_out/data/datasources/local_database_datasource.dart';
import 'package:rush_out/data/repositories/level_repository_impl.dart';
import 'package:rush_out/domain/entities/level.dart';
import 'package:rush_out/domain/repositories/level_repository.dart';
import 'package:rush_out/domain/usecases/get_levels.dart';
import 'package:rush_out/presentation/bloc/level_select_cubit.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../helpers/in_memory_local_database_datasource.dart';

class _FakeLevelRepository implements LevelRepository {
  final List<Level> _levels;
  _FakeLevelRepository(this._levels);

  @override
  Future<List<Level>> getLevels({Difficulty? difficulty}) async => _levels;

  @override
  Future<void> saveLevelProgress({
    required int levelId,
    required Difficulty difficulty,
    required int userMoves,
    required int stars,
  }) async {}

  @override
  Future<void> skipLevel({
    required int levelId,
    required Difficulty difficulty,
  }) async {}

  @override
  Future<int> getRemainingHints() async => 3;

  @override
  Future<int> updateRemainingHints(int delta) async => 3 + delta;

  @override
  Future<InProgressLevelState?> getInProgressLevel(
    int levelId, {
    String? expectedBoardString,
  }) async =>
      null;

  @override
  Future<void> saveInProgressLevel(InProgressLevelState state) async {}

  @override
  Future<void> clearInProgressLevel(int levelId) async {}
}

class _FakeAssetDataSource extends LevelAssetDataSource {
  final List<Level> _levels;
  _FakeAssetDataSource(this._levels);

  @override
  Future<List<Level>> loadBaseCampaignLevels() async => _levels;
}

Level _sampleLevel(int id, int optimalMoves, {int stars = 0, bool unlocked = false}) {
  return Level(
    id: id,
    difficulty: Difficulty.fromOptimalMoves(optimalMoves) ?? Difficulty.hard,
    optimalMoves: optimalMoves,
    boardString: 'oooooo'
        'oooBoo'
        'AAoBoo'
        'oooooo'
        'oooooo'
        'oooooo',
    stars: stars,
    isUnlocked: unlocked,
  );
}

void main() {
  group('Pure Linear Level Journey Tests', () {
    test('LevelSelectCubit preserves pipeline order and computes frontier & total stars', () async {
      final pipelineOrdered = [
        _sampleLevel(1, 5, stars: 3, unlocked: true),
        _sampleLevel(2, 5, unlocked: true),
        _sampleLevel(3, 12, unlocked: false),
        _sampleLevel(4, 22, unlocked: false),
      ];

      final cubit = LevelSelectCubit(
        getLevelsUseCase: GetLevels(_FakeLevelRepository(pipelineOrdered)),
      );
      await cubit.loadLevels();

      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.levels.map((l) => l.id).toList(), [1, 2, 3, 4]);
      // Frontier should be index 1 (id 2, unlocked with 0 stars)
      expect(cubit.state.frontierIndex, 1);
      expect(cubit.state.frontierLevel?.id, 2);
      expect(cubit.state.totalEarnedStars, 3);
      expect(cubit.state.maxPossibleStars, 12);

      await cubit.close();
    });

    test('LevelRepositoryImpl enforces strict linear unlock (#1 unlocked, completing #N unlocks #N+1)', () async {
      final base = [
        _sampleLevel(1, 5),
        _sampleLevel(2, 7),
        _sampleLevel(3, 12), // medium moves, must NOT be unlocked by default
        _sampleLevel(4, 20), // hard moves, must NOT be unlocked by default
      ];

      final repo = LevelRepositoryImpl(
        assetDataSource: _FakeAssetDataSource(base),
        localDataSource: InMemoryLocalDatabaseDataSource(),
      );

      // Initially only Level #1 is unlocked
      final initial = await repo.getLevels();
      expect(initial.map((l) => l.isUnlocked).toList(), [true, false, false, false]);

      // Completing Level #1 unlocks Level #2 only
      await repo.saveLevelProgress(
        levelId: 1,
        difficulty: Difficulty.easy,
        userMoves: 5,
        stars: 3,
      );
      final afterOne = await repo.getLevels();
      expect(afterOne[0].stars, 3);
      expect(afterOne.map((l) => l.isUnlocked).toList(), [true, true, false, false]);

      // Completing Level #2 unlocks Level #3
      await repo.saveLevelProgress(
        levelId: 2,
        difficulty: Difficulty.easy,
        userMoves: 8,
        stars: 2,
      );
      final afterTwo = await repo.getLevels();
      expect(afterTwo[1].stars, 2);
      expect(afterTwo.map((l) => l.isUnlocked).toList(), [true, true, true, false]);

      // Skipping Level #3 marks it 0 stars and unlocks Level #4
      await repo.skipLevel(
        levelId: 3,
        difficulty: Difficulty.medium,
      );
      final afterSkip = await repo.getLevels();
      expect(afterSkip[2].stars, 0);
      expect(afterSkip.map((l) => l.isUnlocked).toList(), [true, true, true, true]);
    });

    test('skipLevel persists explicit is_skipped column in SQLite and enforces active skip cap', () async {
      sqfliteFfiInit();
      final localDb = LocalDatabaseDataSource(
        getDatabasesPathFn: () async => inMemoryDatabasePath,
        openDatabaseFn: (
          path, {
          version,
          onCreate,
          onUpgrade,
        }) {
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

      final base = [
        _sampleLevel(1, 5),
        _sampleLevel(2, 6),
        _sampleLevel(3, 7),
        _sampleLevel(4, 8),
        _sampleLevel(5, 9),
      ];
      final repo = LevelRepositoryImpl(
        assetDataSource: _FakeAssetDataSource(base),
        localDataSource: localDb,
      );

      // Skip 1, 2, 3 -> allowed up to cap (3)
      await repo.skipLevel(levelId: 1, difficulty: Difficulty.easy);
      final row1 = await localDb.getLevelProgress(1);
      expect(row1, isNotNull);
      expect(row1!['is_skipped'], 1);

      await repo.skipLevel(levelId: 2, difficulty: Difficulty.easy);
      await repo.skipLevel(levelId: 3, difficulty: Difficulty.easy);

      // Skipping a 4th consecutive level without solving any skipped level must be rejected
      await expectLater(
        repo.skipLevel(levelId: 4, difficulty: Difficulty.easy),
        throwsStateError,
      );

      final levelsAfter3Skips = await repo.getLevels();
      expect(levelsAfter3Skips[4].isUnlocked, isFalse);

      await localDb.close();
    });
  });
}
