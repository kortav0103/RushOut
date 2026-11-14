import '../../domain/entities/level.dart';
import '../../domain/repositories/level_repository.dart';
import '../datasources/level_asset_datasource.dart';
import '../datasources/local_database_datasource.dart';
import '../models/level_model.dart';

class LevelRepositoryImpl implements LevelRepository {
  final LevelAssetDataSource assetDataSource;
  final LocalDatabaseDataSource localDataSource;

  const LevelRepositoryImpl({
    required this.assetDataSource,
    required this.localDataSource,
  });

  @override
  Future<List<Level>> getLevels({Difficulty? difficulty}) async {
    final baseLevels = await assetDataSource.loadBaseCampaignLevels();
    final progressMap = await localDataSource.getAllLevelProgress();

    final List<Level> merged = [];
    for (int i = 0; i < baseLevels.length; i++) {
      final base = baseLevels[i];
      final row = progressMap[base.id];
      var model = LevelModel.fromProgressMap(base, row);

      // Ensure first level of each difficulty tier is unlocked by default,
      // or if the preceding level was cleared (stars > 0)
      final isFirstInDifficulty =
          base.id == 1 || base.id == 11 || base.id == 21;
      final prevCleared = i > 0 && merged[i - 1].stars > 0;
      if ((isFirstInDifficulty || prevCleared) && !model.isUnlocked) {
        model = LevelModel(
          id: model.id,
          difficulty: model.difficulty,
          optimalMoves: model.optimalMoves,
          boardString: model.boardString,
          clusterSize: model.clusterSize,
          bestMoves: model.bestMoves,
          stars: model.stars,
          isUnlocked: true,
        );
      }

      merged.add(model);
    }

    if (difficulty != null) {
      return merged.where((l) => l.difficulty == difficulty).toList();
    }
    return merged;
  }

  @override
  Future<void> saveLevelProgress({
    required int levelId,
    required Difficulty difficulty,
    required int userMoves,
    required int stars,
  }) async {
    final existing = await localDataSource.getLevelProgress(levelId);
    final oldBestMoves = existing?['best_moves'] as int?;
    final oldStars = (existing?['stars'] as int?) ?? 0;

    final newBestMoves =
        (oldBestMoves == null || userMoves < oldBestMoves)
            ? userMoves
            : oldBestMoves;
    final newStars = stars > oldStars ? stars : oldStars;

    await localDataSource.upsertLevelProgress(
      levelId: levelId,
      difficulty: difficulty.name,
      bestMoves: newBestMoves,
      stars: newStars,
      isUnlocked: true,
    );

    // Unlock the next level in campaign (up to level 30)
    final baseLevels = await assetDataSource.loadBaseCampaignLevels();
    final nextId = levelId + 1;
    final nextLevel = baseLevels.where((l) => l.id == nextId).firstOrNull;
    if (nextLevel != null) {
      final nextExisting = await localDataSource.getLevelProgress(nextId);
      await localDataSource.upsertLevelProgress(
        levelId: nextId,
        difficulty: nextLevel.difficulty.name,
        bestMoves: nextExisting?['best_moves'] as int?,
        stars: (nextExisting?['stars'] as int?) ?? 0,
        isUnlocked: true,
      );
    }
  }
}
