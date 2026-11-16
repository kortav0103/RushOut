import '../entities/move.dart';
import '../repositories/daily_challenge_repository.dart';
import '../repositories/leaderboard_repository.dart';

class SubmitScore {
  final LeaderboardRepository repository;
  final DailyChallengeRepository? dailyRepository;

  const SubmitScore(this.repository, {this.dailyRepository});

  Future<void> call({
    required String playerName,
    required String challengeDate,
    required int movesCount,
    List<Move>? moveHistory,
  }) {
    final daily = dailyRepository;
    if (daily is VerifiedDailyChallengeRepository &&
        moveHistory != null &&
        moveHistory.isNotEmpty) {
      return daily.submitVerifiedScore(
        playerName: playerName,
        challengeDate: challengeDate,
        moveHistory: moveHistory,
      );
    }

    return repository.submitScore(
      playerName: playerName,
      challengeDate: challengeDate,
      movesCount: movesCount,
    );
  }
}
