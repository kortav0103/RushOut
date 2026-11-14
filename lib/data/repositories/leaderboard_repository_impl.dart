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
