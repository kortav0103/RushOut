import '../../core/error/exceptions.dart';
import '../../core/network/network_info.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/repositories/daily_challenge_repository.dart';
import '../datasources/local_database_datasource.dart';
import '../datasources/supabase_remote_datasource.dart';
import '../models/score_model.dart';

class DailyChallengeRepositoryImpl implements DailyChallengeRepository {
  final SupabaseRemoteDataSource remoteDataSource;
  final LocalDatabaseDataSource localDataSource;
  final NetworkInfo networkInfo;

  const DailyChallengeRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  @override
  Future<DailyChallenge> getDailyChallenge(String dateKey) async {
    final isConnected = await networkInfo.isConnected;

    if (isConnected && remoteDataSource.isConfigured) {
      try {
        final remoteChallenge =
            await remoteDataSource.fetchDailyChallenge(dateKey);
        if (remoteChallenge == null) {
          throw EmptyDataException(
            'No Daily Challenge is scheduled for $dateKey yet.',
          );
        }

        // Merge with existing local progress for this date if any
        final existingCache =
            await localDataSource.getCachedDailyChallenge(dateKey);
        final merged = DailyChallengeModel(
          dateKey: remoteChallenge.dateKey,
          boardString: remoteChallenge.boardString,
          optimalMoves: remoteChallenge.optimalMoves,
          isCompleted: existingCache?.isCompleted ?? false,
          userMoves: existingCache?.userMoves,
        );

        await localDataSource.saveDailyChallengeCache(merged);
        return merged;
      } on EmptyDataException {
        rethrow;
      } catch (e) {
        // Graceful offline fallback: attempt to load from SQLite daily_cache
        final cached = await localDataSource.getCachedDailyChallenge(dateKey);
        if (cached != null) {
          return cached;
        }
        rethrow;
      }
    }

    // Offline or Supabase not configured -> check local SQLite daily_cache first
    final cached = await localDataSource.getCachedDailyChallenge(dateKey);
    if (cached != null) {
      return cached;
    }

    if (!isConnected) {
      throw const ServerException(
        'You are offline and today\'s Daily Challenge has not been cached yet. Please connect to the internet and tap Retry.',
      );
    }

    throw const ServerException(
      'Unable to connect to Supabase. Please configure your .env file with valid SUPABASE_URL and SUPABASE_ANON_KEY and tap Retry.',
    );
  }

  @override
  Future<DailyChallenge> saveDailyCompletion({
    required String dateKey,
    required int userMoves,
  }) async {
    final existing = await localDataSource.getCachedDailyChallenge(dateKey);
    if (existing == null) {
      throw const CacheException('Daily challenge cache entry not found.');
    }

    final bestMoves =
        (existing.userMoves == null || userMoves < existing.userMoves!)
            ? userMoves
            : existing.userMoves!;

    final updated = DailyChallengeModel(
      dateKey: existing.dateKey,
      boardString: existing.boardString,
      optimalMoves: existing.optimalMoves,
      isCompleted: true,
      userMoves: bestMoves,
    );

    await localDataSource.saveDailyChallengeCache(updated);
    return updated;
  }
}
