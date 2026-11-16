import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:rush_out/core/services/audio_service.dart';
import 'package:rush_out/core/services/tutorial_service.dart';
import 'package:rush_out/core/utils/level_parser.dart';
import 'package:rush_out/domain/solver/bfs_solver.dart';
import 'package:rush_out/presentation/bloc/game_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  });
}
