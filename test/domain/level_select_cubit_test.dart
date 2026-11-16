import 'package:flutter_test/flutter_test.dart';
import 'package:rush_out/data/datasources/level_asset_datasource.dart';
import 'package:rush_out/data/datasources/local_database_datasource.dart';
import 'package:rush_out/data/repositories/level_repository_impl.dart';
import 'package:rush_out/domain/entities/level.dart';
import 'package:rush_out/domain/repositories/level_repository.dart';
import 'package:rush_out/domain/usecases/get_levels.dart';
import 'package:rush_out/presentation/bloc/level_select_cubit.dart';

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
        localDataSource: LocalDatabaseDataSource(),
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
  });
}
