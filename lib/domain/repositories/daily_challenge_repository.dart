import '../entities/leaderboard_entry.dart';

abstract class DailyChallengeRepository {
  /// Fetches today's Daily Challenge for [dateKey] (`YYYY-MM-DD`),
  /// caching to SQLite and falling back to local cache when offline.
  Future<DailyChallenge> getDailyChallenge(String dateKey);

  /// Marks the daily challenge for [dateKey] as completed locally with [userMoves].
  Future<DailyChallenge> saveDailyCompletion({
    required String dateKey,
    required int userMoves,
  });

  /// Marks the daily challenge score for [dateKey] as submitted to the leaderboard.
  Future<DailyChallenge?> markScoreSubmitted(String dateKey);
}
