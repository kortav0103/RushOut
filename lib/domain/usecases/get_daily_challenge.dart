import '../entities/leaderboard_entry.dart';
import '../repositories/daily_challenge_repository.dart';

class GetDailyChallenge {
  final DailyChallengeRepository repository;

  const GetDailyChallenge(this.repository);

  Future<DailyChallenge> call(String dateKey) {
    return repository.getDailyChallenge(dateKey);
  }
}
