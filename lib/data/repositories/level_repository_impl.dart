import 'dart:convert';
import '../../core/constants/app_constants.dart';
import '../../core/utils/level_parser.dart';
import '../../domain/entities/level.dart';
import '../../domain/entities/move.dart';
import '../../domain/entities/vehicle.dart';
import '../../domain/repositories/level_repository.dart';
import '../datasources/level_asset_datasource.dart';
import '../datasources/local_database_datasource.dart';
import '../models/level_model.dart';

class LevelRepositoryImpl implements LevelRepository {
  static const int maxActiveSkippedLevels = 3;

  final LevelAssetDataSource assetDataSource;
  final LocalDatabaseDataSource localDataSource;
  final Future<void> Function()? onProgressChanged;

  const LevelRepositoryImpl({
    required this.assetDataSource,
    required this.localDataSource,
    this.onProgressChanged,
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

      // Strict linear progression: Level #1 starts unlocked,
      // and completing or skipping Level #N unlocks Level #N+1.
      final isFirstLevel = i == 0;
      final prevProgressed =
          i > 0 && (merged[i - 1].stars > 0 || merged[i - 1].isSkipped);
      if ((isFirstLevel || prevProgressed) && !model.isUnlocked) {
        model = LevelModel(
          id: model.id,
          difficulty: model.difficulty,
          optimalMoves: model.optimalMoves,
          boardString: model.boardString,
          clusterSize: model.clusterSize,
          bestMoves: model.bestMoves,
          stars: model.stars,
          isUnlocked: true,
          isSkipped: model.isSkipped,
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
      isSkipped: false,
    );

    // Unlock the next level in campaign
    final baseLevels = await assetDataSource.loadBaseCampaignLevels();
    final nextId = levelId + 1;
    final nextLevel = baseLevels.where((l) => l.id == nextId).firstOrNull;
    if (nextLevel != null) {
      final nextExisting = await localDataSource.getLevelProgress(nextId);
      final nextStars = (nextExisting?['stars'] as int?) ?? 0;
      final nextSkipped =
          nextStars == 0 && ((nextExisting?['is_skipped'] as int?) ?? 0) == 1;
      await localDataSource.upsertLevelProgress(
        levelId: nextId,
        difficulty: nextLevel.difficulty.name,
        bestMoves: nextExisting?['best_moves'] as int?,
        stars: nextStars,
        isUnlocked: true,
        isSkipped: nextSkipped,
      );
    }

    onProgressChanged?.call();
  }

  @override
  Future<void> skipLevel({
    required int levelId,
    required Difficulty difficulty,
  }) async {
    final allProgress = await localDataSource.getAllLevelProgress();
    final existing = allProgress[levelId];
    final oldBestMoves = existing?['best_moves'] as int?;
    final oldStars = (existing?['stars'] as int?) ?? 0;
    final wasCleared = oldStars > 0;
    final alreadySkipped = ((existing?['is_skipped'] as int?) ?? 0) == 1;

    if (!wasCleared && !alreadySkipped) {
      final activeSkippedCount = allProgress.values.where((row) {
        final stars = (row['stars'] as int?) ?? 0;
        final skipped = (row['is_skipped'] as int?) ?? 0;
        return stars == 0 && skipped == 1;
      }).length;
      if (activeSkippedCount >= maxActiveSkippedLevels) {
        throw StateError(
          'Maximum active skipped levels ($maxActiveSkippedLevels) reached. '
          'Clear a skipped level before skipping another.',
        );
      }
    }

    await localDataSource.upsertLevelProgress(
      levelId: levelId,
      difficulty: difficulty.name,
      bestMoves: oldBestMoves,
      stars: oldStars,
      isUnlocked: true,
      isSkipped: !wasCleared,
    );

    await localDataSource.clearInProgressLevel(levelId);

    final baseLevels = await assetDataSource.loadBaseCampaignLevels();
    final nextId = levelId + 1;
    final nextLevel = baseLevels.where((l) => l.id == nextId).firstOrNull;
    if (nextLevel != null) {
      final nextExisting = allProgress[nextId];
      final nextStars = (nextExisting?['stars'] as int?) ?? 0;
      final nextSkipped =
          nextStars == 0 && ((nextExisting?['is_skipped'] as int?) ?? 0) == 1;
      await localDataSource.upsertLevelProgress(
        levelId: nextId,
        difficulty: nextLevel.difficulty.name,
        bestMoves: nextExisting?['best_moves'] as int?,
        stars: nextStars,
        isUnlocked: true,
        isSkipped: nextSkipped,
      );
    }

    onProgressChanged?.call();
  }

  @override
  Future<InProgressLevelState?> getInProgressLevel(
    int levelId, {
    String? expectedBoardString,
  }) async {
    if (levelId <= 0) return null;
    final row = await localDataSource.getInProgressLevel(levelId);
    if (row == null) return null;

    final savedBoard = row['board_string'] as String?;
    final savedMoves = row['move_count'] as int?;
    final rawHistory = row['move_history'] as String?;
    if (savedBoard == null || savedMoves == null || savedMoves <= 0) {
      await localDataSource.clearInProgressLevel(levelId);
      return null;
    }

    try {
      final parsedSaved = LevelParser.parseToBoardState(savedBoard);
      if (parsedSaved.isWon) {
        await localDataSource.clearInProgressLevel(levelId);
        return null;
      }

      final List<Move> restoredHistory = [];
      if (rawHistory != null && rawHistory.isNotEmpty) {
        final decoded = jsonDecode(rawHistory);
        if (decoded is! List) {
          await localDataSource.clearInProgressLevel(levelId);
          return null;
        }
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            restoredHistory.add(Move.fromJson(item));
          } else if (item is Map) {
            restoredHistory.add(Move.fromJson(Map<String, dynamic>.from(item)));
          } else {
            await localDataSource.clearInProgressLevel(levelId);
            return null;
          }
        }
      }

      if (expectedBoardString != null &&
          !_isCompatibleWithExpectedBoard(
            savedVehicles: parsedSaved.vehicles,
            expectedBoardString: expectedBoardString,
            moveHistory: restoredHistory,
          )) {
        await localDataSource.clearInProgressLevel(levelId);
        return null;
      }

      return InProgressLevelState(
        levelId: levelId,
        boardString: savedBoard,
        moveCount: savedMoves,
        moveHistory: restoredHistory,
      );
    } catch (_) {
      await localDataSource.clearInProgressLevel(levelId);
      return null;
    }
  }

  bool _isCompatibleWithExpectedBoard({
    required List<Vehicle> savedVehicles,
    required String expectedBoardString,
    required List<Move> moveHistory,
  }) {
    final expectedVehicles = LevelParser.parseBoardString(expectedBoardString);
    if (savedVehicles.length != expectedVehicles.length) return false;

    final savedById = {for (final v in savedVehicles) v.id: v};
    final expectedById = {for (final v in expectedVehicles) v.id: v};

    for (final ev in expectedVehicles) {
      final sv = savedById[ev.id];
      if (sv == null) return false;
      if (sv.length != ev.length || sv.isHorizontal != ev.isHorizontal) {
        return false;
      }
      if (ev.isHorizontal && sv.row != ev.row) return false;
      if (!ev.isHorizontal && sv.col != ev.col) return false;
    }

    for (final move in moveHistory) {
      final ev = expectedById[move.vehicleId];
      if (ev == null || !move.isActualMove) return false;
      if (move.fromRow < 0 ||
          move.fromRow >= AppConstants.gridSize ||
          move.toRow < 0 ||
          move.toRow >= AppConstants.gridSize ||
          move.fromCol < 0 ||
          move.fromCol >= AppConstants.gridSize ||
          move.toCol < 0 ||
          move.toCol >= AppConstants.gridSize) {
        return false;
      }
      if (ev.isHorizontal &&
          (move.fromRow != ev.row || move.toRow != ev.row)) {
        return false;
      }
      if (!ev.isHorizontal &&
          (move.fromCol != ev.col || move.toCol != ev.col)) {
        return false;
      }
    }

    return true;
  }

  @override
  Future<void> saveInProgressLevel(InProgressLevelState state) async {
    if (state.levelId <= 0) return;
    if (state.moveCount <= 0) {
      await localDataSource.clearInProgressLevel(state.levelId);
      return;
    }
    final moveHistoryJson =
        jsonEncode(state.moveHistory.map((m) => m.toJson()).toList());
    await localDataSource.saveInProgressLevel(
      levelId: state.levelId,
      boardString: state.boardString,
      moveCount: state.moveCount,
      moveHistoryJson: moveHistoryJson,
    );
  }

  @override
  Future<void> clearInProgressLevel(int levelId) async {
    if (levelId <= 0) return;
    await localDataSource.clearInProgressLevel(levelId);
  }
}
