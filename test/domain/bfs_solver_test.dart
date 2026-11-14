import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:rush_out/core/utils/level_parser.dart';
import 'package:rush_out/domain/engine/board_engine.dart';
import 'package:rush_out/domain/entities/level.dart';
import 'package:rush_out/domain/solver/bfs_solver.dart';

void main() {
  group('BfsSolver Tests', () {
    test('solves a simple 2-move board and returns accurate first hint move', () {
      final state = LevelParser.parseToBoardState(
        'oooooo'
        'oooBoo'
        'AAoBoo'
        'oooooo'
        'oooooo'
        'oooooo',
        optimalMoves: 2,
      );

      final hint = BfsSolver.findNextMove(state);
      expect(hint, isNotNull);
      expect(hint!.vehicleId, 'B');
      expect(hint.fromRow, 1);
      expect(hint.fromCol, 3);

      final fullPath = BfsSolver.solve(state);
      expect(fullPath, isNotNull);
      expect(fullPath!.length, 2);

      var current = state;
      for (final move in fullPath) {
        current = BoardEngine.applyMove(current, move);
      }
      expect(current.isWon, isTrue);
    });

    test('finds valid shortest-path solutions matching optimal_moves on Easy and Medium campaign levels', () {
      final file = File('assets/levels/rush1000.txt');
      expect(file.existsSync(), isTrue);

      final levels = LevelParser.parseCampaignLevels(file.readAsStringSync());
      final easySamples =
          levels.where((l) => l.difficulty == Difficulty.easy).take(5).toList();
      final mediumSamples = levels
          .where((l) => l.difficulty == Difficulty.medium)
          .take(5)
          .toList();

      for (final level in [...easySamples, ...mediumSamples]) {
        final initialState = LevelParser.parseToBoardState(
          level.boardString,
          optimalMoves: level.optimalMoves,
        );
        final solution = BfsSolver.solve(initialState);

        expect(
          solution,
          isNotNull,
          reason: 'Level ${level.id} (${level.difficulty.label}) should be solvable',
        );
        expect(
          solution!.length,
          equals(level.optimalMoves),
          reason:
              'Level ${level.id} shortest path length (${solution.length}) should match optimalMoves (${level.optimalMoves})',
        );

        // Verify replaying the BFS moves reaches the winning state
        var simState = initialState;
        for (final move in solution) {
          expect(BoardEngine.isValidMove(simState, move), isTrue);
          simState = BoardEngine.applyMove(simState, move);
        }
        expect(simState.isWon, isTrue);
      }
    });

    test('returns null on unsolvable boards', () {
      // Target car A on row 2 is permanently blocked by two vertical 3-cell trucks B and C
      // stacked in column 4 (wait: 3+3 = 6 cells in col 4, so neither B nor C can ever move!)
      final unsolvableState = LevelParser.parseToBoardState(
        'ooooBo'
        'ooooBo'
        'AAooBo'
        'ooooCo'
        'ooooCo'
        'ooooCo',
      );

      final solution = BfsSolver.solve(unsolvableState);
      expect(solution, isNull);
      expect(BfsSolver.findNextMove(unsolvableState), isNull);
    });
  });
}
