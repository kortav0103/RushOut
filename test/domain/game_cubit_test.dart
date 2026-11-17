import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rush_out/core/services/audio_service.dart';
import 'package:rush_out/data/datasources/level_asset_datasource.dart';
import 'package:rush_out/data/repositories/level_repository_impl.dart';
import 'package:rush_out/domain/entities/level.dart';
import 'package:rush_out/domain/entities/move.dart';
import 'package:rush_out/domain/repositories/level_repository.dart';
import 'package:rush_out/domain/usecases/save_progress.dart';
import 'package:rush_out/presentation/bloc/daily_cubit.dart';
import 'package:rush_out/presentation/bloc/game_cubit.dart';
import 'package:rush_out/presentation/screens/game_screen.dart';
import 'package:rush_out/presentation/widgets/parking_board_widget.dart';
import '../helpers/in_memory_local_database_datasource.dart';

class _DelayedReadInMemoryDb extends InMemoryLocalDatabaseDataSource {
  final Duration readDelay;
  _DelayedReadInMemoryDb(this.readDelay);

  @override
  Future<Map<String, dynamic>?> getInProgressLevel(int levelId) async {
    await Future<void>.delayed(readDelay);
    return super.getInProgressLevel(levelId);
  }
}

class _FailingSaveProgressRepo extends Fake implements LevelRepository {
  final LevelRepository _delegate;
  _FailingSaveProgressRepo(this._delegate);

  @override
  Future<InProgressLevelState?> getInProgressLevel(
    int levelId, {
    String? expectedBoardString,
  }) =>
      _delegate.getInProgressLevel(
        levelId,
        expectedBoardString: expectedBoardString,
      );

  @override
  Future<void> saveInProgressLevel(InProgressLevelState state) =>
      _delegate.saveInProgressLevel(state);

  @override
  Future<void> clearInProgressLevel(int levelId) =>
      _delegate.clearInProgressLevel(levelId);

  @override
  Future<void> saveLevelProgress({
    required int levelId,
    required Difficulty difficulty,
    required int userMoves,
    required int stars,
  }) async {
    throw Exception('Disk write failed');
  }
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
      expect(cubit.state.remainingHints, 2);

      // Request hint -> runs BfsSolver in background Isolate and decrements remainingHints
      await cubit.requestHint();
      expect(cubit.state.activeHint, isNotNull);
      expect(cubit.state.activeHint!.vehicleId, 'B');
      expect(cubit.state.remainingHints, 1);

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
      // No 3-star bonus hint -> remainingHints stays 1
      expect(cubit.state.remainingHints, 1);

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
      expect(cubit.state.remainingHints, 2);

      // Start async BFS hint while B is at row 3, then immediately undo before Isolate returns
      final hintFuture = cubit.requestHint();
      cubit.undo();
      expect(cubit.state.boardState.moveCount, 0);

      await hintFuture;

      expect(cubit.state.activeHint, isNull);
      expect(cubit.state.isComputingHint, isFalse);
      expect(cubit.state.remainingHints, 2);
    });

    test('defaults to 2 hints per level without 3-star bonus or cross-level persistence', () async {
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

      final cubit1 = GameCubit(
        level: level1,
        initialLevels: const [level1, level2],
        audioService: audio,
        saveProgressUseCase: saveProgress,
      );
      expect(cubit1.state.remainingHints, 2);

      // Spend 1 hint (2 -> 1), then earn 3 stars -> no +1 bonus (stays 1)
      await cubit1.requestHint();
      expect(cubit1.state.remainingHints, 1);
      await cubit1.onVehicleDragEnd('B', draggedRow: 3.0, draggedCol: 3.0);
      await cubit1.onVehicleDragEnd('A', draggedRow: 2.0, draggedCol: 4.0);
      expect(cubit1.state.earnedStars, 3);
      expect(cubit1.state.remainingHints, 1);

      // Loading next level resets hints to 2
      cubit1.loadNextLevel();
      expect(cubit1.state.level.id, 2);
      expect(cubit1.state.remainingHints, 2);
      await cubit1.close();
    });

    test('serializes undo() -> reset() without leaving stale board and rejects late restore or incompatible board', () async {
      final delayedDb = _DelayedReadInMemoryDb(const Duration(milliseconds: 35));
      final repo = LevelRepositoryImpl(
        assetDataSource: LevelAssetDataSource(),
        localDataSource: delayedDb,
      );

      // 1. Seed valid in-progress state for level 1, then hit reset() before slow restore returns
      await repo.saveInProgressLevel(
        const InProgressLevelState(
          levelId: 1,
          boardString: 'oooooo'
              'oooooo'
              'AAoooo'
              'oooBoo'
              'oooBoo'
              'oooooo',
          moveCount: 1,
          moveHistory: [
            Move(vehicleId: 'B', fromRow: 1, fromCol: 3, toRow: 3, toCol: 3),
          ],
        ),
      );

      final cubitReset = GameCubit(
        level: sampleLevel,
        audioService: AudioService(enablePlatformAudio: false),
        saveProgressUseCase: SaveProgress(repo),
      );
      // Player hits reset immediately before async restore completes
      cubitReset.reset();
      await Future<void>.delayed(const Duration(milliseconds: 70));

      expect(cubitReset.state.boardState.moveCount, 0);
      expect(cubitReset.state.boardState.getVehicleById('B')!.row, 1);
      expect(await delayedDb.getInProgressLevel(1), isNull);

      // 2. Make 2 moves, then rapidly call undo() followed immediately by reset()
      await cubitReset.onVehicleDragEnd('B', draggedRow: 3.0, draggedCol: 3.0);
      await cubitReset.onVehicleDragEnd('A', draggedRow: 2.0, draggedCol: 1.0);
      expect(cubitReset.state.boardState.moveCount, 2);

      cubitReset.undo();
      cubitReset.reset();
      await Future<void>.delayed(const Duration(milliseconds: 70));

      expect(cubitReset.state.boardState.moveCount, 0);
      expect(await delayedDb.getInProgressLevel(1), isNull);
      await cubitReset.close();

      // 3. Incompatible saved board (has vehicle C instead of B) must be ignored and cleared
      await delayedDb.saveInProgressLevel(
        levelId: 1,
        boardString: 'CCoooo'
            'oooooo'
            'AAoooo'
            'oooooo'
            'oooooo'
            'oooooo',
        moveCount: 3,
        moveHistoryJson: jsonEncode(const []),
      );

      final cubitIncompatible = GameCubit(
        level: sampleLevel,
        audioService: AudioService(enablePlatformAudio: false),
        saveProgressUseCase: SaveProgress(repo),
      );
      await Future<void>.delayed(const Duration(milliseconds: 70));

      expect(cubitIncompatible.state.boardState.moveCount, 0);
      expect(cubitIncompatible.state.boardState.getVehicleById('B'), isNotNull);
      expect(cubitIncompatible.state.boardState.getVehicleById('C'), isNull);
      expect(await delayedDb.getInProgressLevel(1), isNull);
      await cubitIncompatible.close();
    });

    test('GameCubit exposes saveErrorMessage when saveProgressUseCase throws on win [FUNC-03]', () async {
      final baseRepo = LevelRepositoryImpl(
        assetDataSource: LevelAssetDataSource(),
        localDataSource: InMemoryLocalDatabaseDataSource(),
      );
      final failingRepo = _FailingSaveProgressRepo(baseRepo);
      final failingCubit = GameCubit(
        level: sampleLevel,
        audioService: AudioService(enablePlatformAudio: false),
        saveProgressUseCase: SaveProgress(failingRepo),
      );

      await failingCubit.onVehicleDragEnd('B', draggedRow: 3.0, draggedCol: 3.0);
      await failingCubit.onVehicleDragEnd('A', draggedRow: 2.0, draggedCol: 4.0);

      expect(failingCubit.state.isWon, isTrue);
      expect(failingCubit.state.saveErrorMessage, isNotNull);
      expect(failingCubit.state.saveErrorMessage, contains('Could not save'));

      await failingCubit.close();
    });

    testWidgets('GameScreen shows SnackBar warning when saveProgressUseCase throws [FUNC-03]', (tester) async {
      final baseRepo = LevelRepositoryImpl(
        assetDataSource: LevelAssetDataSource(),
        localDataSource: InMemoryLocalDatabaseDataSource(),
      );
      final failingRepo = _FailingSaveProgressRepo(baseRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(
            initialLevel: const Level(
              id: 1,
              difficulty: Difficulty.easy,
              optimalMoves: 1,
              boardString: 'oooooo'
                  'oooooo'
                  'oooAAo'
                  'oooooo'
                  'oooooo'
                  'oooooo',
              isUnlocked: true,
            ),
            allLevels: const [],
            audioService: AudioService(enablePlatformAudio: false),
            saveProgressUseCase: SaveProgress(failingRepo),
          ),
        ),
      );
      await tester.pump();

      final boardWidth = tester.getSize(find.byType(ParkingBoardWidget)).width;
      final cellSize = (boardWidth * (1 - 0.09)) / 6.0;
      final center = tester.getCenter(find.text('↔').first);
      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(20.0, 0));
      await gesture.moveBy(Offset(cellSize - 20.0, 0));
      await gesture.up();

      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(
        find.textContaining('Could not save level progress locally'),
        findsOneWidget,
      );
    });
  });
}
