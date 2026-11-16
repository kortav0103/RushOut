import '../entities/level.dart';

abstract class LevelRepository {
  /// Loads all 4,050 campaign levels merged with saved user progress (stars, bestMoves, isUnlocked).
  Future<List<Level>> getLevels({Difficulty? difficulty});

  /// Saves progress for a completed level and unlocks the next level in the same difficulty.
  Future<void> saveLevelProgress({
    required int levelId,
    required Difficulty difficulty,
    required int userMoves,
    required int stars,
  });

  /// Marks a level as skipped (0 stars if not previously cleared) and unlocks the next level.
  Future<void> skipLevel({
    required int levelId,
    required Difficulty difficulty,
  });

  /// Returns the persisted remaining hint quota (defaults to 3 for new players).
  Future<int> getRemainingHints();

  /// Atomically applies [delta] (e.g. -1 on hint use, +1 on first 3-star win)
  /// to the persisted hint wallet (clamped to >= 0) and returns the updated balance.
  Future<int> updateRemainingHints(int delta);
}
