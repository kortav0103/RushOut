import '../entities/level.dart';
import '../repositories/level_repository.dart';

class GetLevels {
  final LevelRepository repository;

  const GetLevels(this.repository);

  Future<List<Level>> call({Difficulty? difficulty}) {
    return repository.getLevels(difficulty: difficulty);
  }
}
