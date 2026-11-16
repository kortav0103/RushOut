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
