import '../entities/leaderboard_entry.dart';
import '../entities/move.dart';

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

/// Extended Daily Challenge repository supporting solved board snapshots,
/// best move history preservation, and server-verified anti-cheat submission.
abstract class VerifiedDailyChallengeRepository
    implements DailyChallengeRepository {
  /// Marks [dateKey] as completed locally, persisting [solvedBoardString] and
  /// [moveHistory] when this run is the player's best valid solution.
  Future<DailyChallenge> saveVerifiedCompletion({
    required String dateKey,
    required int userMoves,
    required String solvedBoardString,
    required List<Move> moveHistory,
  });

  /// Verifies [moveHistory] against the challenge's starting board and submits
  /// the move sequence to the server anti-cheat verifier RPC.
  Future<DailyChallenge> submitVerifiedScore({
    required String playerName,
    required String challengeDate,
    required List<Move> moveHistory,
  });
}
