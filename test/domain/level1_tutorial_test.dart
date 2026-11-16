import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rush_out/core/network/network_info.dart';
import 'package:rush_out/core/services/audio_service.dart';
import 'package:rush_out/core/services/tutorial_service.dart';
import 'package:rush_out/core/utils/level_parser.dart';
import 'package:rush_out/data/datasources/level_asset_datasource.dart';
import 'package:rush_out/data/datasources/supabase_remote_datasource.dart';
import 'package:rush_out/data/repositories/daily_challenge_repository_impl.dart';
import 'package:rush_out/data/repositories/leaderboard_repository_impl.dart';
import 'package:rush_out/data/repositories/level_repository_impl.dart';
import 'package:rush_out/domain/entities/level.dart';
import 'package:rush_out/domain/solver/bfs_solver.dart';
import 'package:rush_out/domain/usecases/get_leaderboard.dart';
import 'package:rush_out/domain/usecases/get_levels.dart';
import 'package:rush_out/domain/usecases/save_progress.dart';
import 'package:rush_out/domain/usecases/submit_score.dart';
import 'package:rush_out/presentation/bloc/game_cubit.dart';
import 'package:rush_out/presentation/screens/game_screen.dart';
import 'package:rush_out/presentation/screens/home_screen.dart';
import 'package:rush_out/presentation/widgets/parking_board_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/in_memory_local_database_datasource.dart';

class _FakeAssetDataSource extends LevelAssetDataSource {
  final List<Level> _levels;
  _FakeAssetDataSource(this._levels);

  @override
  Future<List<Level>> loadBaseCampaignLevels() async => _levels;
}

class _FakeNetworkInfo implements NetworkInfo {
  @override
  Future<bool> get isConnected async => false;
}

void main() {
  group('Solver-Driven Level #1 Tutorial Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('hasCompletedTutorial defaults to false and persists true', () async {
      final service = TutorialService();
      expect(await service.hasCompletedTutorial(), isFalse);

      await service.setTutorialCompleted(true);
      expect(await service.hasCompletedTutorial(), isTrue);

      final freshService = TutorialService();
      expect(await freshService.hasCompletedTutorial(), isTrue);
    });

    test('Level #1 tutorial uses exact BfsSolver steps, locks non-active vehicles, and transitions cleanly', () async {
      final file = File('assets/levels/rush1000.txt');
      expect(file.existsSync(), isTrue);

      final levels = LevelParser.parseCampaignLevels(file.readAsStringSync());
      final level1 = levels[0];
      final level2 = levels[1];

      final initialBoard = LevelParser.parseToBoardState(
        level1.boardString,
        optimalMoves: level1.optimalMoves,
      );
      final expectedSolution = BfsSolver.solve(initialBoard);
      expect(expectedSolution, isNotNull);
      expect(expectedSolution!.isNotEmpty, isTrue);

      final tutorialService = TutorialService();
      final audioService = AudioService(enablePlatformAudio: false);
      final cubit = GameCubit(
        level: level1,
        audioService: audioService,
        tutorialService: tutorialService,
        isTutorialMode: true,
      );

      expect(cubit.state.isTutorialMode, isTrue);
      expect(cubit.state.isLoadingTutorial, isTrue);
      if (cubit.state.isLoadingTutorial) {
        await cubit.stream.firstWhere((s) => !s.isLoadingTutorial);
      }
      expect(cubit.state.tutorialSteps, expectedSolution);
      expect(cubit.state.tutorialStepIndex, 0);

      // Verify non-active vehicle cannot be moved
      final firstMove = cubit.state.currentTutorialMove!;
      final lockedVehicle = cubit.state.boardState.vehicles
          .firstWhere((v) => v.id != firstMove.vehicleId);
      final lockedBounds = cubit.dragBoundsForTutorialVehicle(lockedVehicle)!;
      expect(lockedBounds.minRow, lockedVehicle.row);
      expect(lockedBounds.maxRow, lockedVehicle.row);
      expect(lockedBounds.minCol, lockedVehicle.col);
      expect(lockedBounds.maxCol, lockedVehicle.col);

      await cubit.onVehicleDragEnd(
        lockedVehicle.id,
        draggedRow: lockedVehicle.row.toDouble(),
        draggedCol: lockedVehicle.col.toDouble(),
      );
      expect(cubit.state.tutorialStepIndex, 0);

      // Execute every solver step in exact sequence
      for (int i = 0; i < expectedSolution.length; i++) {
        final step = expectedSolution[i];
        expect(cubit.state.currentTutorialMove, step);
        expect(cubit.state.unlockedVehicleIds, {step.vehicleId});

        if (step.vehicleId == 'A') {
          expect(
            cubit.state.tutorialInstruction,
            'Slide the pink car out to the exit!',
          );
        } else {
          expect(
            cubit.state.tutorialInstruction,
            'Slide the blocking vehicle to clear the path',
          );
        }

        await cubit.onVehicleDragEnd(
          step.vehicleId,
          draggedRow: step.toRow.toDouble(),
          draggedCol: step.toCol.toDouble(),
        );
      }

      expect(cubit.state.isWon, isTrue);
      expect(cubit.state.boardState.isWon, isTrue);
      expect(await tutorialService.hasCompletedTutorial(), isTrue);

      // Transitioning to Level #2 runs free-form without tutorial locks
      cubit.loadLevel(level2);
      expect(cubit.state.isTutorialMode, isFalse);
      expect(cubit.state.unlockedVehicleIds, isNull);
      expect(cubit.state.tutorialInstruction, isNull);

      await cubit.close();
    });

    test('Tutorial prevents hint waste, avoids partial-move penalty, and supports skipTutorial', () async {
      final file = File('assets/levels/rush1000.txt');
      final levels = LevelParser.parseCampaignLevels(file.readAsStringSync());
      final level1 = levels[0];

      final tutorialService = TutorialService();
      final audioService = AudioService(enablePlatformAudio: false);
      final cubit = GameCubit(
        level: level1,
        audioService: audioService,
        tutorialService: tutorialService,
        isTutorialMode: true,
      );
      if (cubit.state.isLoadingTutorial) {
        await cubit.stream.firstWhere((s) => !s.isLoadingTutorial);
      }

      final initialHints = cubit.state.remainingHints;
      await cubit.requestHint();
      expect(cubit.state.remainingHints, initialHints);
      expect(cubit.state.tutorialDetailInstruction, isNotNull);

      // Find a step with distance >= 2 if present, or test same-cell drag
      final multiCellStep = cubit.state.tutorialSteps.firstWhere(
        (m) => (m.toRow - m.fromRow).abs() + (m.toCol - m.fromCol).abs() >= 2,
        orElse: () => cubit.state.tutorialSteps.first,
      );
      if ((multiCellStep.toRow - multiCellStep.fromRow).abs() +
              (multiCellStep.toCol - multiCellStep.fromCol).abs() >=
          2) {
        final stepIdx = cubit.state.tutorialSteps.indexOf(multiCellStep);
        for (int i = 0; i < stepIdx; i++) {
          final s = cubit.state.tutorialSteps[i];
          await cubit.onVehicleDragEnd(
            s.vehicleId,
            draggedRow: s.toRow.toDouble(),
            draggedCol: s.toCol.toDouble(),
          );
        }
        final movesBeforePartial = cubit.state.boardState.moveCount;
        final midRow = ((multiCellStep.fromRow + multiCellStep.toRow) / 2).floorToDouble();
        final midCol = ((multiCellStep.fromCol + multiCellStep.toCol) / 2).floorToDouble();
        await cubit.onVehicleDragEnd(
          multiCellStep.vehicleId,
          draggedRow: midRow,
          draggedCol: midCol,
        );
        expect(cubit.state.boardState.moveCount, movesBeforePartial);
        expect(cubit.state.tutorialStepIndex, stepIdx);
      }

      // Skip tutorial marks completed and unlocks free play
      await cubit.skipTutorial();
      expect(cubit.state.isTutorialMode, isFalse);
      expect(cubit.state.unlockedVehicleIds, isNull);
      expect(await tutorialService.hasCompletedTutorial(), isTrue);

      await cubit.close();
    });

    List<Level> sampleCampaignLevels() {
      const twoMoveBoard = 'oooCCo'
          'oooBoo'
          'AAoBoo'
          'oooooo'
          'oooooo'
          'oooooo';
      return const [
        Level(
          id: 1,
          difficulty: Difficulty.easy,
          optimalMoves: 2,
          boardString: twoMoveBoard,
          isUnlocked: true,
        ),
        Level(
          id: 2,
          difficulty: Difficulty.easy,
          optimalMoves: 2,
          boardString: twoMoveBoard,
          isUnlocked: false,
        ),
        Level(
          id: 3,
          difficulty: Difficulty.easy,
          optimalMoves: 2,
          boardString: twoMoveBoard,
          isUnlocked: false,
        ),
        Level(
          id: 4,
          difficulty: Difficulty.easy,
          optimalMoves: 2,
          boardString: twoMoveBoard,
          isUnlocked: false,
        ),
      ];
    }

    Future<void> pumpFrames(WidgetTester tester, {int ms = 300}) async {
      await tester.pump();
      await tester.pump(Duration(milliseconds: ms));
      await tester.pump(const Duration(milliseconds: 100));
    }

    Future<void> pumpUntilFound(
      WidgetTester tester,
      Finder finder, {
      int maxAttempts = 40,
    }) async {
      for (int i = 0; i < maxAttempts; i++) {
        if (finder.evaluate().isNotEmpty) return;
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> dragVehicleByCells(
      WidgetTester tester,
      Finder finder, {
      required int dxCells,
      required int dyCells,
    }) async {
      final boardWidth = tester.getSize(find.byType(ParkingBoardWidget)).width;
      final innerWidth = boardWidth * (1 - 0.09);
      final cellSize = innerWidth / 6.0;
      final center = tester.getCenter(finder);
      final gesture = await tester.startGesture(center);
      // Cross touch slop (18px) in the drag direction first
      final slopDx = dxCells == 0 ? 0.0 : (dxCells > 0 ? 20.0 : -20.0);
      final slopDy = dyCells == 0 ? 0.0 : (dyCells > 0 ? 20.0 : -20.0);
      await gesture.moveBy(Offset(slopDx, slopDy));
      await gesture.moveBy(
        Offset(dxCells * cellSize - slopDx, dyCells * cellSize - slopDy),
      );
      await gesture.up();
      await pumpFrames(tester, ms: 200);
    }

    Future<void> solveTwoMoveBoardAndOpenWinDialog(WidgetTester tester) async {
      await dragVehicleByCells(tester, find.text('↕'), dxCells: 0, dyCells: 2);
      await dragVehicleByCells(
        tester,
        find.text('↔').first,
        dxCells: 4,
        dyCells: 0,
      );
      // Wait for 520ms escape animation + WinDialog open
      await tester.pump(const Duration(milliseconds: 650));
      await pumpFrames(tester, ms: 300);
    }

    testWidgets(
      'first-launch tutorial Back to Levels from WinDialog navigates to LevelSelectScreen instead of HomeScreen',
      (tester) async {
        final audio = AudioService(enablePlatformAudio: false);
        final localDb = InMemoryLocalDatabaseDataSource();
        final levels = sampleCampaignLevels();
        final levelRepo = LevelRepositoryImpl(
          assetDataSource: _FakeAssetDataSource(levels),
          localDataSource: localDb,
        );
        final remoteDs = SupabaseRemoteDataSource();
        final netInfo = _FakeNetworkInfo();
        final tutorialService = TutorialService();

        await tester.pumpWidget(
          MaterialApp(
            home: HomeScreen(
              audioService: audio,
              tutorialService: tutorialService,
              getLevelsUseCase: GetLevels(levelRepo),
              saveProgressUseCase: SaveProgress(levelRepo),
              dailyRepository: DailyChallengeRepositoryImpl(
                remoteDataSource: remoteDs,
                localDataSource: localDb,
                networkInfo: netInfo,
              ),
              submitScoreUseCase: SubmitScore(
                LeaderboardRepositoryImpl(
                  remoteDataSource: remoteDs,
                  networkInfo: netInfo,
                ),
              ),
              getLeaderboardUseCase: GetLeaderboard(
                LeaderboardRepositoryImpl(
                  remoteDataSource: remoteDs,
                  networkInfo: netInfo,
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('PLAY CAMPAIGN'));
        await pumpUntilFound(tester, find.text('Welcome to RushOut!'));

        expect(find.text('Welcome to RushOut!'), findsOneWidget);
        await tester.tap(find.text("Let's Drive!"));
        await pumpFrames(tester, ms: 400);
        await pumpUntilFound(tester, find.text('Step 1/2'));

        await solveTwoMoveBoardAndOpenWinDialog(tester);
        expect(find.text('TUTORIAL COMPLETE!'), findsOneWidget);

        // Tap Back to Levels (grid icon)
        await tester.tap(find.byIcon(Icons.grid_view_rounded));
        await pumpUntilFound(tester, find.text('Select Level'));

        // Must land on LevelSelectScreen, NOT HomeScreen!
        expect(find.text('Select Level'), findsOneWidget);
        expect(find.text('PLAY CAMPAIGN'), findsNothing);
      },
    );

    testWidgets(
      'replaying tutorial from Level #N returns to Level #N on Next instead of jumping to Level #2',
      (tester) async {
        final audio = AudioService(enablePlatformAudio: false);
        final localDb = InMemoryLocalDatabaseDataSource();
        final levels = sampleCampaignLevels();
        final levelRepo = LevelRepositoryImpl(
          assetDataSource: _FakeAssetDataSource(levels),
          localDataSource: localDb,
        );
        final tutorialService = TutorialService();
        await tutorialService.setTutorialCompleted(true);

        await tester.pumpWidget(
          MaterialApp(
            home: GameScreen(
              initialLevel: levels[2].copyWith(isUnlocked: true), // Level #3
              allLevels: levels,
              audioService: audio,
              saveProgressUseCase: SaveProgress(levelRepo),
              tutorialService: tutorialService,
            ),
          ),
        );
        await pumpFrames(tester, ms: 300);

        expect(find.text('Level #3'), findsOneWidget);

        // Open How to Play (?) and tap Tutorial
        await tester.tap(find.byIcon(Icons.help_outline_rounded));
        await pumpFrames(tester, ms: 300);
        await tester.tap(find.text('Tutorial'));
        await pumpUntilFound(tester, find.text('Step 1/2'));

        expect(find.text('Level #1'), findsOneWidget);

        await solveTwoMoveBoardAndOpenWinDialog(tester);
        expect(find.text('TUTORIAL COMPLETE!'), findsOneWidget);

        // Tap Next -> must return to Level #3, NOT jump to Level #2
        await tester.tap(find.text('Next'));
        await pumpUntilFound(tester, find.text('Level #3'));

        expect(find.text('Level #3'), findsOneWidget);
        expect(find.text('Level #2'), findsNothing);
      },
    );

    testWidgets(
      'Skip Level is locked at 0 moves and unlocks next level with isUnlocked == true after minimum moves',
      (tester) async {
        final audio = AudioService(enablePlatformAudio: false);
        final localDb = InMemoryLocalDatabaseDataSource();
        final levels = sampleCampaignLevels();
        final levelRepo = LevelRepositoryImpl(
          assetDataSource: _FakeAssetDataSource(levels),
          localDataSource: localDb,
        );
        final tutorialService = TutorialService();
        await tutorialService.setTutorialCompleted(true);

        await tester.pumpWidget(
          MaterialApp(
            home: GameScreen(
              initialLevel: levels[0], // Level #1, 0 moves
              allLevels: levels,
              audioService: audio,
              saveProgressUseCase: SaveProgress(levelRepo),
              tutorialService: tutorialService,
            ),
          ),
        );
        await pumpFrames(tester, ms: 300);

        // At 0 moves, tapping Skip must NOT open the Skip confirmation dialog
        await tester.tap(find.byIcon(Icons.skip_next_rounded));
        await pumpFrames(tester, ms: 300);
        expect(find.text('Skip Level #1?'), findsNothing);
        expect(find.text('Level #1'), findsOneWidget);

        // Make 2 non-winning moves to unlock Skip (requiredMovesToSkip == 2 for optimalMoves 2)
        await dragVehicleByCells(tester, find.text('↕'), dxCells: 0, dyCells: 2);
        await dragVehicleByCells(tester, find.text('↕'), dxCells: 0, dyCells: -2);

        await tester.tap(find.byIcon(Icons.skip_next_rounded));
        await pumpFrames(tester, ms: 300);
        expect(find.text('Skip Level #1?'), findsOneWidget);

        await tester.tap(find.text('Skip Level'));
        await pumpFrames(tester, ms: 300);

        // Now on Level #2 and its persisted/state level has isUnlocked == true
        expect(find.text('Level #2'), findsOneWidget);
        final row1 = await localDb.getLevelProgress(1);
        final row2 = await localDb.getLevelProgress(2);
        expect(row1?['is_skipped'], 1);
        expect(row2?['is_unlocked'], 1);
      },
    );
  });
}
