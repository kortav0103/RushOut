import 'package:flutter_test/flutter_test.dart';
import 'package:rush_out/core/services/audio_service.dart';
import 'package:rush_out/data/datasources/level_asset_datasource.dart';
import 'package:rush_out/data/repositories/level_repository_impl.dart';
import 'package:rush_out/domain/entities/leaderboard_entry.dart';
import 'package:rush_out/domain/entities/level.dart';
import 'package:rush_out/domain/repositories/daily_challenge_repository.dart';
import 'package:rush_out/domain/repositories/leaderboard_repository.dart';
import 'package:rush_out/domain/usecases/save_progress.dart';
import 'package:rush_out/domain/usecases/submit_score.dart';
import 'package:rush_out/presentation/bloc/daily_cubit.dart';
import 'package:rush_out/presentation/bloc/game_cubit.dart';
import '../helpers/in_memory_local_database_datasource.dart';

class _StubDailyRepo implements DailyChallengeRepository {
  final DailyChallenge challenge;
  _StubDailyRepo(this.challenge);

  @override
  Future<DailyChallenge> getDailyChallenge(String dateKey) async => challenge;

  @override
  Future<DailyChallenge> saveDailyCompletion({
    required String dateKey,
    required int userMoves,
  }) async =>
      challenge.copyWith(isCompleted: true, userMoves: userMoves);

  @override
  Future<DailyChallenge?> markScoreSubmitted(String dateKey) async =>
      challenge.copyWith(scoreSubmitted: true);
}

class _StubLeaderboardRepo implements LeaderboardRepository {
  @override
  Future<List<LeaderboardEntry>> getLeaderboard(String challengeDate) async =>
      const [];

  @override
  Future<void> submitScore({
    required String playerName,
    required String challengeDate,
    required int movesCount,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameCubit Tests', () {
    const sampleLevel = Level(
      id: 1,
      difficulty: Difficulty.easy,
      optimalMoves: 2,
      boardString: 'oooooo'
          'oooBoo'
          'AAoBoo'
          'oooooo'
          'oooooo'
          'oooooo',
      isUnlocked: true,
    );

    late GameCubit cubit;

    setUp(() {
      cubit = GameCubit(
        level: sampleLevel,
        audioService: AudioService(enablePlatformAudio: false),
      );
    });

    tearDown(() async {
      await cubit.close();
    });

    test('manages board state, async Isolate hint, undo, reset, and win detection', () async {
      expect(cubit.state.boardState.moveCount, 0);
      expect(cubit.state.isWon, isFalse);
      expect(cubit.state.remainingHints, 3);

      // Request hint -> runs BfsSolver in background Isolate and decrements remainingHints
      await cubit.requestHint();
      expect(cubit.state.activeHint, isNotNull);
      expect(cubit.state.activeHint!.vehicleId, 'B');
      expect(cubit.state.remainingHints, 2);

      // Drag B down to row 3
      cubit.onVehicleDragStart('B');
      await cubit.onVehicleDragEnd('B', draggedRow: 3.1, draggedCol: 3.0);

      expect(cubit.state.boardState.moveCount, 1);
      expect(cubit.state.activeHint, isNull);
      expect(cubit.state.canUndo, isTrue);

      // Undo -> back to 0 moves
      cubit.undo();
      expect(cubit.state.boardState.moveCount, 0);
      expect(cubit.state.boardState.getVehicleById('B')!.row, 1);

      // Redo move 1 (B -> row 3) and move 2 (A -> col 4) to win
      await cubit.onVehicleDragEnd('B', draggedRow: 3.0, draggedCol: 3.0);
      await cubit.onVehicleDragEnd('A', draggedRow: 2.0, draggedCol: 4.0);

      expect(cubit.state.isWon, isTrue);
      expect(cubit.state.earnedStars, 3);
      expect(cubit.state.level.bestMoves, 2);
      expect(cubit.state.level.stars, 3);
      // Earned 3 stars for the first time -> +1 bonus hint (2 + 1 = 3)
      expect(cubit.state.remainingHints, 3);

      // Reset -> restores initial state
      cubit.reset();
      expect(cubit.state.isWon, isFalse);
      expect(cubit.state.boardState.moveCount, 0);
      expect(cubit.state.earnedStars, 0);
    });

    test('DailyCubit UTC date formatting and nickname profanity filter work accurately', () {
      // 2026-11-15 02:30:00 in UTC+7 is 2026-11-14 19:30:00 UTC
      final localEarlyMorning = DateTime.utc(2026, 11, 14, 19, 30);
      expect(DailyCubit.formatTodayDateKey(localEarlyMorning), '2026-11-14');

      expect(DailyCubit.validatePlayerName('SpeedRacer_VN'), isNull);
      expect(DailyCubit.validatePlayerName('A'), isNotNull); // too short
      expect(DailyCubit.validatePlayerName('bad link http://spam.com'), isNotNull);
      expect(DailyCubit.validatePlayerName('player fuck 123'), isNotNull);
    });

    test('requestHint ignores stale Isolate result and preserves quota when player undoes or resets mid-solve', () async {
      // Move B out of the way so board is 1 move away from winning
      await cubit.onVehicleDragEnd('B', draggedRow: 3.0, draggedCol: 3.0);
      expect(cubit.state.boardState.moveCount, 1);
      expect(cubit.state.remainingHints, 3);

      // Start async BFS hint while B is at row 3, then immediately undo before Isolate returns
      final hintFuture = cubit.requestHint();
      cubit.undo();
      expect(cubit.state.boardState.moveCount, 0);

      await hintFuture;

      expect(cubit.state.activeHint, isNull);
      expect(cubit.state.isComputingHint, isFalse);
      expect(cubit.state.remainingHints, 3);
    });

    test('DailyCubit requestHint ignores stale Isolate result and preserves quota when player resets mid-solve', () async {
      final dailyCubit = DailyCubit(
        dailyRepository: _StubDailyRepo(
          const DailyChallenge(
            dateKey: '2026-11-16',
            boardString: 'oooooo'
                'oooBoo'
                'AAoBoo'
                'oooooo'
                'oooooo'
                'oooooo',
            optimalMoves: 2,
          ),
        ),
        submitScoreUseCase: SubmitScore(_StubLeaderboardRepo()),
        audioService: AudioService(enablePlatformAudio: false),
        initialDateKey: '2026-11-16',
      );
      await dailyCubit.loadDailyChallenge();
      await dailyCubit.onVehicleDragEnd('B', draggedRow: 3.0, draggedCol: 3.0);
      expect(dailyCubit.state.remainingHints, 3);

      final hintFuture = dailyCubit.requestHint();
      dailyCubit.reset();

      await hintFuture;

      expect(dailyCubit.state.activeHint, isNull);
      expect(dailyCubit.state.isComputingHint, isFalse);
      expect(dailyCubit.state.remainingHints, 3);
      await dailyCubit.close();
    });

    test('persists spent hint quota and first-time 3-star +1 bonus hint across exit and re-entry', () async {
      final localDb = InMemoryLocalDatabaseDataSource();
      final repo = LevelRepositoryImpl(
        assetDataSource: LevelAssetDataSource(),
        localDataSource: localDb,
      );
      final saveProgress = SaveProgress(repo);
      final audio = AudioService(enablePlatformAudio: false);

      const level1 = Level(
        id: 1,
        difficulty: Difficulty.easy,
        optimalMoves: 2,
        boardString: 'oooooo'
            'oooBoo'
            'AAoBoo'
            'oooooo'
            'oooooo'
            'oooooo',
        isUnlocked: true,
      );
      const level2 = Level(
        id: 2,
        difficulty: Difficulty.easy,
        optimalMoves: 2,
        boardString: 'oooooo'
            'oooBoo'
            'AAoBoo'
            'oooooo'
            'oooooo'
            'oooooo',
        isUnlocked: true,
      );

      // Session 1: spend 1 hint (3 -> 2), then exit without solving
      final session1 = GameCubit(
        level: level1,
        audioService: audio,
        saveProgressUseCase: saveProgress,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await session1.requestHint();
      expect(session1.state.remainingHints, 2);
      await session1.close();

      // Session 2: re-enter -> spent quota must still be 2 (not reset to 3)
      final session2 = GameCubit(
        level: level1,
        audioService: audio,
        saveProgressUseCase: saveProgress,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(session2.state.remainingHints, 2);

      // Earn 3 stars for the first time on level 1 -> +1 bonus hint (2 -> 3)
      await session2.onVehicleDragEnd('B', draggedRow: 3.0, draggedCol: 3.0);
      await session2.onVehicleDragEnd('A', draggedRow: 2.0, draggedCol: 4.0);
      expect(session2.state.earnedStars, 3);
      expect(session2.state.remainingHints, 3);
      await session2.close();

      // Session 3: enter level 2 -> earn 3 stars for first time -> 3 -> 4 hints
      final session3 = GameCubit(
        level: level2,
        audioService: audio,
        saveProgressUseCase: saveProgress,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(session3.state.remainingHints, 3);
      await session3.onVehicleDragEnd('B', draggedRow: 3.0, draggedCol: 3.0);
      await session3.onVehicleDragEnd('A', draggedRow: 2.0, draggedCol: 4.0);
      expect(session3.state.remainingHints, 4);
      await session3.close();

      // Session 4: exit and re-enter -> +1 bonus hint (total 4) is preserved!
      final session4 = GameCubit(
        level: level2.copyWith(stars: 3, bestMoves: 2),
        audioService: audio,
        saveProgressUseCase: saveProgress,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(session4.state.remainingHints, 4);
      await session4.close();
    });
  });
}
