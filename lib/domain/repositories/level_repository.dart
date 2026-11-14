import '../entities/level.dart';

abstract class LevelRepository {
  /// Loads all 30 campaign levels merged with saved user progress (stars, bestMoves, isUnlocked).
  Future<List<Level>> getLevels({Difficulty? difficulty});

  /// Saves progress for a completed level and unlocks the next level in the same difficulty.
  Future<void> saveLevelProgress({
    required int levelId,
    required Difficulty difficulty,
    required int userMoves,
    required int stars,
  });
}
