import 'dart:collection';
import '../../core/constants/app_constants.dart';
import '../engine/board_engine.dart';
import '../entities/board_state.dart';
import '../entities/move.dart';

class BfsSolver {
  const BfsSolver();

  /// Finds the complete shortest sequence of [Move]s from [initialState]
  /// until the target red car (`'A'`) reaches `(row: 2, col: 4)`.
  ///
  /// Returns:
  /// - Empty list `[]` if [initialState] is already in a winning state.
  /// - `List<Move>` containing the shortest path if solvable.
  /// - `null` if the board is unsolvable.
  static List<Move>? solve(
    BoardState initialState, {
    int maxVisitedStates = 150000,
  }) {
    final target = initialState.targetVehicle;
    if (target == null ||
        !target.isHorizontal ||
        target.row != AppConstants.exitRow) {
      return null;
    }

    if (initialState.isWon) {
      return const <Move>[];
    }

    final Queue<BoardState> queue = Queue<BoardState>();
    final Set<String> visited = <String>{};

    final startState = initialState.copyWith(
      moveCount: 0,
      moveHistory: const <Move>[],
    );

    visited.add(startState.toBoardString());
    queue.add(startState);

    while (queue.isNotEmpty) {
      if (visited.length > maxVisitedStates) {
        return null;
      }

      final current = queue.removeFirst();
      final validMoves = BoardEngine.generateAllValidMoves(current);

      for (final move in validMoves) {
        final nextState = BoardEngine.applyMove(
          current,
          move,
          recordHistory: true,
        );

        if (nextState.isWon) {
          return nextState.moveHistory;
        }

        final key = nextState.toBoardString();
        if (visited.add(key)) {
          queue.add(nextState);
        }
      }
    }

    return null;
  }

  /// Returns the **first [Move]** of the shortest path to solve [currentState],
  /// used by the UI Hint feature to highlight the vehicle and direction.
  /// Returns `null` if the board is already solved or unsolvable.
  static Move? findNextMove(
    BoardState currentState, {
    int maxVisitedStates = 150000,
  }) {
    final path = solve(currentState, maxVisitedStates: maxVisitedStates);
    if (path == null || path.isEmpty) {
      return null;
    }
    return path.first;
  }

  /// Alias for [findNextMove] for semantic convenience.
  static Move? getHint(BoardState currentState) => findNextMove(currentState);
}
