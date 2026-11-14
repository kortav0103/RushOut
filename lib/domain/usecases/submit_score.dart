import '../entities/leaderboard_entry.dart';
import '../repositories/leaderboard_repository.dart';

class SubmitScore {
  final LeaderboardRepository repository;

  const SubmitScore(this.repository);

  Future<void> call({
    required String playerName,
    required String challengeDate,
    required int movesCount,
  }) {
    return repository.submitScore(
      playerName: playerName,
      challengeDate: challengeDate,
      movesCount: movesCount,
    );
  }
}

class GetLeaderboard {
  final LeaderboardRepository repository;

  const GetLeaderboard(this.repository);

  Future<List<LeaderboardEntry>> call(String challengeDate) {
    return repository.getLeaderboard(challengeDate);
  }
}
