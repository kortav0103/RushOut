import 'package:equatable/equatable.dart';
import '../entities/leaderboard_entry.dart';

class PlayerLeaderboardRank extends Equatable {
  final int rank;
  final LeaderboardEntry entry;

  const PlayerLeaderboardRank({
    required this.rank,
    required this.entry,
  });

  @override
  List<Object?> get props => [rank, entry];
}

class LeaderboardPage extends Equatable {
  final List<LeaderboardEntry> entries;
  final PlayerLeaderboardRank? myRank;
  final String? currentUserId;
  final bool hasMore;

  const LeaderboardPage({
    required this.entries,
    this.myRank,
    this.currentUserId,
    this.hasMore = false,
  });

  @override
  List<Object?> get props => [entries, myRank, currentUserId, hasMore];
}

abstract class LeaderboardRepository {
  static const int defaultPageSize = 20;

  /// Fetches leaderboard scores for [challengeDate] (`YYYY-MM-DD`) ordered by moves_count ascending.
  Future<List<LeaderboardEntry>> getLeaderboard(String challengeDate);

  /// Fetches a paginated leaderboard slice for [challengeDate] along with the
  /// authenticated player's rank summary (if available).
  Future<LeaderboardPage> getLeaderboardPage(
    String challengeDate, {
    int limit = defaultPageSize,
    int offset = 0,
    bool includeMyRank = true,
  });

  /// Submits a player's score for [challengeDate] to Supabase.
  Future<void> submitScore({
    required String playerName,
    required String challengeDate,
    required int movesCount,
  });
}
