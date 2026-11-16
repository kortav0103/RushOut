import 'dart:math' as math;
import '../../core/error/exceptions.dart';
import '../../core/network/network_info.dart';
import '../../core/utils/level_parser.dart';
import '../../domain/engine/board_engine.dart';
import '../../domain/entities/board_state.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/entities/move.dart';
import '../../domain/repositories/daily_challenge_repository.dart';
import '../datasources/local_database_datasource.dart';
import '../datasources/supabase_remote_datasource.dart';
import '../models/daily_challenge_model.dart';

class DailyChallengeRepositoryImpl implements VerifiedDailyChallengeRepository {
  final SupabaseRemoteDataSource remoteDataSource;
  final LocalDatabaseDataSource localDataSource;
  final NetworkInfo networkInfo;

  const DailyChallengeRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  /// Replays [moveHistory] step-by-step against [initialBoardString] using
  /// Rush Hour physics (axis lock, 0..5 bounds, collision detection) and
  /// asserts that target vehicle `'A'` reaches `(row: 2, col: 4)`.
  static BoardState verifySolutionReplay({
    required String initialBoardString,
    required List<Move> moveHistory,
    int optimalMoves = 1,
  }) {
    if (moveHistory.isEmpty) {
      throw const ServerException(
        'Move history cannot be empty when submitting a Daily Challenge score.',
      );
    }

    var board = LevelParser.parseToBoardState(
      initialBoardString,
      optimalMoves: optimalMoves,
    );

    for (int i = 0; i < moveHistory.length; i++) {
      final move = moveHistory[i];
      if (!move.isActualMove || (move.deltaRow != 0 && move.deltaCol != 0)) {
        throw ServerException(
          'Invalid move at step ${i + 1}: diagonal or zero-step move.',
        );
      }
      if (!BoardEngine.isValidMove(board, move)) {
        throw ServerException(
          'Illegal move at step ${i + 1} for vehicle "${move.vehicleId}".',
        );
      }
      board = BoardEngine.applyMove(board, move, recordHistory: true);
    }

    if (!board.isWon) {
      throw const ServerException(
        'Move history does not solve the puzzle (vehicle A did not reach exit).',
      );
    }

    if (optimalMoves > 0 && board.moveCount < optimalMoves) {
      throw ServerException(
        'Move history length (${board.moveCount}) is below puzzle optimal moves ($optimalMoves).',
      );
    }

    return board;
  }

  Future<DailyChallengeModel?> _safeReadCache(String dateKey) async {
    try {
      return await localDataSource.getCachedDailyChallenge(dateKey);
    } on CacheException {
      return null;
    }
  }

  @override
  Future<DailyChallenge> getDailyChallenge(String dateKey) async {
    final isConnected = await networkInfo.isConnected;
    final existingCache = await _safeReadCache(dateKey);

    if (isConnected && remoteDataSource.isConfigured) {
      try {
        final remoteChallenge =
            await remoteDataSource.fetchDailyChallenge(dateKey);
        if (remoteChallenge == null) {
          throw EmptyDataException(
            'No Daily Challenge is scheduled for $dateKey yet.',
          );
        }

        // Only keep local completion snapshot if it belongs to the same board
        final sameBoard = existingCache != null &&
            existingCache.boardString == remoteChallenge.boardString;

        UserDailySubmission? serverSubmission;
        try {
          serverSubmission =
              await remoteDataSource.fetchUserDailySubmission(dateKey);
        } catch (_) {
          // Best-effort check; local cache fallback applies if submission lookup fails.
        }

        final hasLocalWin = sameBoard && existingCache.isCompleted;
        final hasServerSubmit = serverSubmission != null;
        final mergedSubmitted =
            hasServerSubmit || (sameBoard && existingCache.scoreSubmitted);
        final mergedCompleted = hasLocalWin || mergedSubmitted;

        int? mergedUserMoves = sameBoard ? existingCache.userMoves : null;
        if (serverSubmission != null) {
          mergedUserMoves = mergedUserMoves != null
              ? math.min(mergedUserMoves, serverSubmission.movesCount)
              : serverSubmission.movesCount;
        }

        final merged = DailyChallengeModel(
          dateKey: remoteChallenge.dateKey,
          boardString: remoteChallenge.boardString,
          optimalMoves: remoteChallenge.optimalMoves,
          isCompleted: mergedCompleted,
          userMoves: mergedUserMoves,
          solvedBoardString: sameBoard ? existingCache.solvedBoardString : null,
          bestMoveHistory:
              sameBoard ? existingCache.bestMoveHistory : const [],
          scoreSubmitted: mergedSubmitted,
          submittedMoves: serverSubmission?.movesCount ??
              (sameBoard ? existingCache.submittedMoves : null),
          submittedPlayerName: serverSubmission?.playerName ??
              (sameBoard ? existingCache.submittedPlayerName : null),
        );

        await localDataSource.saveDailyChallengeCache(merged);
        return merged;
      } on EmptyDataException {
        rethrow;
      } catch (e) {
        if (existingCache != null) {
          return existingCache;
        }
        rethrow;
      }
    }

    if (existingCache != null) {
      return existingCache;
    }

    if (!isConnected) {
      throw const ServerException(
        'You are offline and today\'s Daily Challenge has not been cached yet. Please connect to the internet and tap Retry.',
      );
    }

    throw const ServerException(
      'Unable to connect to Supabase. Please check your build configuration and tap Retry.',
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
      solvedBoardString: existing.solvedBoardString,
      bestMoveHistory: existing.bestMoveHistory,
      scoreSubmitted: existing.scoreSubmitted,
      submittedMoves: existing.submittedMoves,
      submittedPlayerName: existing.submittedPlayerName,
    );

    await localDataSource.saveDailyChallengeCache(updated);
    return updated;
  }

  @override
  Future<DailyChallenge> saveVerifiedCompletion({
    required String dateKey,
    required int userMoves,
    required String solvedBoardString,
    required List<Move> moveHistory,
  }) async {
    final existing = await localDataSource.getCachedDailyChallenge(dateKey);
    if (existing == null) {
      throw const CacheException('Daily challenge cache entry not found.');
    }

    final replayed = verifySolutionReplay(
      initialBoardString: existing.boardString,
      moveHistory: moveHistory,
      optimalMoves: existing.optimalMoves,
    );
    final verifiedSolvedBoard = replayed.toBoardString();
    final verifiedMoves = replayed.moveCount;

    final shouldReplaceBest = existing.userMoves == null ||
        existing.bestMoveHistory.isEmpty ||
        existing.solvedBoardString == null ||
        verifiedMoves < existing.userMoves!;

    final updated = DailyChallengeModel(
      dateKey: existing.dateKey,
      boardString: existing.boardString,
      optimalMoves: existing.optimalMoves,
      isCompleted: true,
      userMoves: shouldReplaceBest ? verifiedMoves : existing.userMoves,
      solvedBoardString:
          shouldReplaceBest ? verifiedSolvedBoard : existing.solvedBoardString,
      bestMoveHistory: shouldReplaceBest
          ? List<Move>.unmodifiable(moveHistory)
          : existing.bestMoveHistory,
      scoreSubmitted: existing.scoreSubmitted,
      submittedMoves: existing.submittedMoves,
      submittedPlayerName: existing.submittedPlayerName,
    );

    await localDataSource.saveDailyChallengeCache(updated);
    return updated;
  }

  @override
  Future<DailyChallenge> submitVerifiedScore({
    required String playerName,
    required String challengeDate,
    required List<Move> moveHistory,
  }) async {
    final connected = await networkInfo.isConnected;
    if (!connected) {
      throw const ServerException(
        'Cannot submit score while offline. Please check your internet connection.',
      );
    }

    final existing =
        await _safeReadCache(challengeDate);
    if (existing != null) {
      if (existing.scoreSubmitted) {
        throw const ServerException(
          'You have already submitted a score for today\'s Daily Challenge.',
        );
      }
      final replayed = verifySolutionReplay(
        initialBoardString: existing.boardString,
        moveHistory: moveHistory,
        optimalMoves: existing.optimalMoves,
      );

      final cleanName = playerName.trim();
      await remoteDataSource.submitVerifiedScore(
        playerName: cleanName,
        challengeDate: challengeDate,
        moveHistory: moveHistory,
      );

      final isBetterLocal = existing.userMoves == null ||
          existing.bestMoveHistory.isEmpty ||
          replayed.moveCount < existing.userMoves!;

      final updated = DailyChallengeModel(
        dateKey: existing.dateKey,
        boardString: existing.boardString,
        optimalMoves: existing.optimalMoves,
        isCompleted: true,
        userMoves: isBetterLocal ? replayed.moveCount : existing.userMoves,
        solvedBoardString: isBetterLocal
            ? replayed.toBoardString()
            : existing.solvedBoardString,
        bestMoveHistory: isBetterLocal
            ? List<Move>.unmodifiable(moveHistory)
            : existing.bestMoveHistory,
        scoreSubmitted: true,
        submittedMoves: replayed.moveCount,
        submittedPlayerName: cleanName,
      );
      await localDataSource.saveDailyChallengeCache(updated);
      return updated;
    }

    final cleanName = playerName.trim();
    await remoteDataSource.submitVerifiedScore(
      playerName: cleanName,
      challengeDate: challengeDate,
      moveHistory: moveHistory,
    );

    return DailyChallenge(
      dateKey: challengeDate,
      boardString: '',
      optimalMoves: 1,
      isCompleted: true,
      userMoves: moveHistory.length,
      bestMoveHistory: List<Move>.unmodifiable(moveHistory),
      scoreSubmitted: true,
      submittedMoves: moveHistory.length,
      submittedPlayerName: cleanName,
    );
  }

  @override
  Future<DailyChallenge?> markScoreSubmitted(String dateKey) async {
    final existing = await localDataSource.getCachedDailyChallenge(dateKey);
    if (existing == null) return null;
    final updated = DailyChallengeModel(
      dateKey: existing.dateKey,
      boardString: existing.boardString,
      optimalMoves: existing.optimalMoves,
      isCompleted: true,
      userMoves: existing.userMoves,
      solvedBoardString: existing.solvedBoardString,
      bestMoveHistory: existing.bestMoveHistory,
      scoreSubmitted: true,
      submittedMoves: existing.submittedMoves ?? existing.userMoves,
      submittedPlayerName: existing.submittedPlayerName,
    );
    await localDataSource.saveDailyChallengeCache(updated);
    return updated;
  }
}
