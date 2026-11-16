import '../entities/leaderboard_entry.dart';
import '../repositories/leaderboard_repository.dart';

class GetLeaderboard {
  final LeaderboardRepository repository;

  const GetLeaderboard(this.repository);

  Future<List<LeaderboardEntry>> call(String challengeDate) {
    return repository.getLeaderboard(challengeDate);
  }
}
