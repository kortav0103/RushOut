import '../../domain/entities/level.dart';

class LevelModel extends Level {
  const LevelModel({
    required super.id,
    required super.difficulty,
    required super.optimalMoves,
    required super.boardString,
    super.clusterSize = 0,
    super.bestMoves,
    super.stars = 0,
    super.isUnlocked = false,
  });

  factory LevelModel.fromEntity(Level level) {
    return LevelModel(
      id: level.id,
      difficulty: level.difficulty,
      optimalMoves: level.optimalMoves,
      boardString: level.boardString,
      clusterSize: level.clusterSize,
      bestMoves: level.bestMoves,
      stars: level.stars,
      isUnlocked: level.isUnlocked,
    );
  }

  factory LevelModel.fromProgressMap(
    Level baseLevel,
    Map<String, dynamic>? progressRow,
  ) {
    if (progressRow == null) {
      return LevelModel.fromEntity(baseLevel);
    }
    return LevelModel(
      id: baseLevel.id,
      difficulty: baseLevel.difficulty,
      optimalMoves: baseLevel.optimalMoves,
      boardString: baseLevel.boardString,
      clusterSize: baseLevel.clusterSize,
      bestMoves: progressRow['best_moves'] as int?,
      stars: (progressRow['stars'] as int?) ?? 0,
      isUnlocked:
          ((progressRow['is_unlocked'] as int?) ?? (baseLevel.isUnlocked ? 1 : 0)) ==
              1,
    );
  }

  Map<String, dynamic> toProgressMap() {
    return {
      'level_id': id,
      'difficulty': difficulty.name,
      'best_moves': bestMoves,
      'stars': stars,
      'is_unlocked': isUnlocked ? 1 : 0,
    };
  }
}
