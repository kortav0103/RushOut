import '../entities/leaderboard_entry.dart';

abstract class LeaderboardRepository {
  /// Fetches top 20 leaderboard scores for [challengeDate] (`YYYY-MM-DD`) ordered by moves_count ascending.
  Future<List<LeaderboardEntry>> getLeaderboard(String challengeDate);

  /// Submits a player's score for [challengeDate] to Supabase.
  Future<void> submitScore({
    required String playerName,
    required String challengeDate,
    required int movesCount,
  });
}
