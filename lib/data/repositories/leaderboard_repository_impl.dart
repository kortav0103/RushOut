import '../../core/error/exceptions.dart';
import '../../core/network/network_info.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/repositories/leaderboard_repository.dart';
import '../datasources/supabase_remote_datasource.dart';
import '../models/score_model.dart';

class LeaderboardRepositoryImpl implements LeaderboardRepository {
  final SupabaseRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  const LeaderboardRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<List<LeaderboardEntry>> getLeaderboard(String challengeDate) async {
    final connected = await networkInfo.isConnected;
    if (!connected) {
      throw const ServerException(
        'No internet connection. Please connect to the network and tap Retry.',
      );
    }
    return remoteDataSource.fetchLeaderboard(challengeDate);
  }

  @override
  Future<LeaderboardPage> getLeaderboardPage(
    String challengeDate, {
    int limit = LeaderboardRepository.defaultPageSize,
    int offset = 0,
    bool includeMyRank = true,
  }) async {
    final connected = await networkInfo.isConnected;
    if (!connected) {
      throw const ServerException(
        'No internet connection. Please connect to the network and tap Retry.',
      );
    }

    final safeLimit = limit.clamp(1, 50);
    final safeOffset = offset < 0 ? 0 : offset;

    final fetched = await remoteDataSource.fetchLeaderboard(
      challengeDate,
      limit: safeLimit + 1,
      offset: safeOffset,
    );
    final hasMore = fetched.length > safeLimit;
    final pageEntries = hasMore
        ? fetched.take(safeLimit).toList(growable: false)
        : fetched;

    PlayerLeaderboardRank? myRank;
    if (includeMyRank) {
      myRank = await remoteDataSource.fetchPlayerLeaderboardRank(challengeDate);
    }

    final currentUserId = remoteDataSource.currentUserId;
    if (myRank == null && includeMyRank && safeOffset == 0 && currentUserId != null) {
      for (int i = 0; i < pageEntries.length; i++) {
        final entry = pageEntries[i];
        if (entry.userId == currentUserId) {
          myRank = PlayerLeaderboardRank(rank: i + 1, entry: entry);
          break;
        }
      }
    }

    return LeaderboardPage(
      entries: pageEntries,
      myRank: myRank,
      currentUserId: currentUserId,
      hasMore: hasMore,
    );
  }

  @override
  Future<void> submitScore({
    required String playerName,
    required String challengeDate,
    required int movesCount,
  }) async {
    final connected = await networkInfo.isConnected;
    if (!connected) {
      throw const ServerException(
        'Cannot submit score while offline. Please check your internet connection.',
      );
    }
    final model = ScoreModel(
      playerName: playerName.trim(),
      challengeDate: challengeDate,
      movesCount: movesCount,
    );
    await remoteDataSource.submitScore(model);
  }
}
