import '../engine/board_engine.dart';
import '../entities/level.dart';
import '../repositories/level_repository.dart';

class SaveProgress {
  final LevelRepository repository;

  const SaveProgress(this.repository);

  Future<int> call({
    required int levelId,
    required Difficulty difficulty,
    required int userMoves,
    required int optimalMoves,
  }) async {
    final stars = BoardEngine.calculateStars(
      userMoves: userMoves,
      optimalMoves: optimalMoves,
    );
    await repository.saveLevelProgress(
      levelId: levelId,
      difficulty: difficulty,
      userMoves: userMoves,
      stars: stars,
    );
    return stars;
  }

  Future<void> skipLevel({
    required int levelId,
    required Difficulty difficulty,
  }) {
    return repository.skipLevel(
      levelId: levelId,
      difficulty: difficulty,
    );
  }
}
