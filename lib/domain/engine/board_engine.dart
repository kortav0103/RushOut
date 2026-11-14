import 'package:equatable/equatable.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/level_parser.dart';
import '../entities/board_state.dart';
import '../entities/move.dart';
import '../entities/vehicle.dart';

class MovementBounds extends Equatable {
  final int minRow;
  final int maxRow;
  final int minCol;
  final int maxCol;

  const MovementBounds({
    required this.minRow,
    required this.maxRow,
    required this.minCol,
    required this.maxCol,
  });

  double clampRow(double row) =>
      row.clamp(minRow.toDouble(), maxRow.toDouble());

  double clampCol(double col) =>
      col.clamp(minCol.toDouble(), maxCol.toDouble());

  int snapRow(double row) => clampRow(row).round();

  int snapCol(double col) => clampCol(col).round();

  bool contains(int row, int col) =>
      row >= minRow && row <= maxRow && col >= minCol && col <= maxCol;

  @override
  List<Object?> get props => [minRow, maxRow, minCol, maxCol];
}

class BoardEngine {
  const BoardEngine();

  /// Builds a 6x6 matrix containing the occupying vehicle ID at each cell, or null if empty.
  static List<List<String?>> buildOccupancyGrid(
    List<Vehicle> vehicles, {
    String? excludeVehicleId,
  }) {
    final grid = List<List<String?>>.generate(
      AppConstants.gridSize,
      (_) => List<String?>.filled(AppConstants.gridSize, null),
    );

    for (final v in vehicles) {
      if (v.id == excludeVehicleId) continue;
      for (int i = 0; i < v.length; i++) {
        final r = v.isHorizontal ? v.row : v.row + i;
        final c = v.isHorizontal ? v.col + i : v.col;
        if (r >= 0 &&
            r < AppConstants.gridSize &&
            c >= 0 &&
            c < AppConstants.gridSize) {
          grid[r][c] = v.id;
        }
      }
    }
    return grid;
  }

  /// Calculates valid movement bounds `[minCol, maxCol]` (if horizontal)
  /// or `[minRow, maxRow]` (if vertical) for [vehicleId] so it cannot jump
  /// over other vehicles or leave `0..5` grid boundaries.
  static MovementBounds getMovementBounds(BoardState state, String vehicleId) {
    final vehicle = state.getVehicleById(vehicleId);
    if (vehicle == null) {
      throw ArgumentError('Vehicle with id "$vehicleId" not found on board.');
    }

    final grid = buildOccupancyGrid(
      state.vehicles,
      excludeVehicleId: vehicleId,
    );

    if (vehicle.isHorizontal) {
      int minCol = vehicle.col;
      while (minCol > 0 && grid[vehicle.row][minCol - 1] == null) {
        minCol--;
      }

      int maxCol = vehicle.col;
      while (maxCol + vehicle.length < AppConstants.gridSize &&
          grid[vehicle.row][maxCol + vehicle.length] == null) {
        maxCol++;
      }

      return MovementBounds(
        minRow: vehicle.row,
        maxRow: vehicle.row,
        minCol: minCol,
        maxCol: maxCol,
      );
    } else {
      int minRow = vehicle.row;
      while (minRow > 0 && grid[minRow - 1][vehicle.col] == null) {
        minRow--;
      }

      int maxRow = vehicle.row;
      while (maxRow + vehicle.length < AppConstants.gridSize &&
          grid[maxRow + vehicle.length][vehicle.col] == null) {
        maxRow++;
      }

      return MovementBounds(
        minRow: minRow,
        maxRow: maxRow,
        minCol: vehicle.col,
        maxCol: vehicle.col,
      );
    }
  }

  /// Checks whether moving [vehicleId] to `(toRow, toCol)` is legal
  /// (respects axis lock, grid bounds, and does not collide or jump over obstacles).
  static bool canMoveTo(
    BoardState state,
    String vehicleId, {
    required int toRow,
    required int toCol,
  }) {
    final vehicle = state.getVehicleById(vehicleId);
    if (vehicle == null) return false;

    if (vehicle.isHorizontal && toRow != vehicle.row) {
      return false;
    }
    if (!vehicle.isHorizontal && toCol != vehicle.col) {
      return false;
    }

    final bounds = getMovementBounds(state, vehicleId);
    return bounds.contains(toRow, toCol);
  }

  /// Validates a [Move] object against the current [BoardState].
  static bool isValidMove(BoardState state, Move move) {
    final vehicle = state.getVehicleById(move.vehicleId);
    if (vehicle == null) return false;
    if (vehicle.row != move.fromRow || vehicle.col != move.fromCol) {
      return false;
    }
    if (!move.isActualMove) return false;
    return canMoveTo(
      state,
      move.vehicleId,
      toRow: move.toRow,
      toCol: move.toCol,
    );
  }

  /// Moves a vehicle to `(toRow, toCol)`.
  /// - If [clamp] is false (default), invalid moves or moves that don't change
  ///   the cell return [state] unchanged.
  /// - If [clamp] is true, the target position is locked to the vehicle's axis
  ///   and clamped within its valid [MovementBounds].
  static BoardState moveVehicle(
    BoardState state,
    String vehicleId, {
    int? toRow,
    int? toCol,
    bool clamp = false,
  }) {
    final vehicle = state.getVehicleById(vehicleId);
    if (vehicle == null) return state;

    int targetRow = toRow ?? vehicle.row;
    int targetCol = toCol ?? vehicle.col;

    if (clamp) {
      final bounds = getMovementBounds(state, vehicleId);
      targetRow = vehicle.isHorizontal
          ? vehicle.row
          : bounds.snapRow(targetRow.toDouble());
      targetCol = vehicle.isHorizontal
          ? bounds.snapCol(targetCol.toDouble())
          : vehicle.col;
    } else {
      if (!canMoveTo(state, vehicleId, toRow: targetRow, toCol: targetCol)) {
        return state;
      }
    }

    if (targetRow == vehicle.row && targetCol == vehicle.col) {
      return state;
    }

    final move = Move(
      vehicleId: vehicleId,
      fromRow: vehicle.row,
      fromCol: vehicle.col,
      toRow: targetRow,
      toCol: targetCol,
    );

    return applyMove(state, move, recordHistory: true);
  }

  /// Snaps a dragged floating-point grid position `(draggedRow, draggedCol)`
  /// to the nearest valid integer cell within [MovementBounds], and commits
  /// the move if the final cell differs from the start cell.
  static BoardState snapVehicle(
    BoardState state,
    String vehicleId, {
    required double draggedRow,
    required double draggedCol,
  }) {
    final vehicle = state.getVehicleById(vehicleId);
    if (vehicle == null) return state;

    final bounds = getMovementBounds(state, vehicleId);
    final snappedRow =
        vehicle.isHorizontal ? vehicle.row : bounds.snapRow(draggedRow);
    final snappedCol =
        vehicle.isHorizontal ? bounds.snapCol(draggedCol) : vehicle.col;

    if (snappedRow == vehicle.row && snappedCol == vehicle.col) {
      return state;
    }

    final move = Move(
      vehicleId: vehicleId,
      fromRow: vehicle.row,
      fromCol: vehicle.col,
      toRow: snappedRow,
      toCol: snappedCol,
    );

    return applyMove(state, move, recordHistory: true);
  }

  /// Applies a validated [Move] to [state].
  static BoardState applyMove(
    BoardState state,
    Move move, {
    bool recordHistory = true,
  }) {
    final updatedVehicles = state.vehicles.map((v) {
      if (v.id == move.vehicleId) {
        return v.copyWith(row: move.toRow, col: move.toCol);
      }
      return v;
    }).toList(growable: false);

    return state.copyWith(
      vehicles: updatedVehicles,
      moveCount: state.moveCount + 1,
      moveHistory:
          recordHistory ? [...state.moveHistory, move] : state.moveHistory,
    );
  }

  /// Undoes the last move on the undo stack ([BoardState.moveHistory]).
  /// Decrements `moveCount` by 1 (down to 0) and restores the vehicle position.
  static BoardState undo(BoardState state) {
    if (state.moveHistory.isEmpty) {
      return state;
    }

    final lastMove = state.moveHistory.last;
    final remainingHistory =
        state.moveHistory.sublist(0, state.moveHistory.length - 1);

    final updatedVehicles = state.vehicles.map((v) {
      if (v.id == lastMove.vehicleId) {
        return v.copyWith(row: lastMove.fromRow, col: lastMove.fromCol);
      }
      return v;
    }).toList(growable: false);

    return state.copyWith(
      vehicles: updatedVehicles,
      moveCount: state.moveCount > 0 ? state.moveCount - 1 : 0,
      moveHistory: remainingHistory,
    );
  }

  /// Resets the board to its initial state by unwinding all moves or re-parsing [initialBoardString].
  static BoardState reset(BoardState state, {String? initialBoardString}) {
    if (initialBoardString != null) {
      return LevelParser.parseToBoardState(
        initialBoardString,
        optimalMoves: state.optimalMoves,
      );
    }

    var current = state;
    while (current.canUndo) {
      current = undo(current);
    }
    return current.copyWith(moveCount: 0, moveHistory: const []);
  }

  /// Checks whether the target red car ('A') has reached the exit position (row: 2, col: 4).
  static bool isWinningState(BoardState state) => state.isWon;

  /// Calculates star rating (1..3) according to section 3.5:
  /// - 3 Stars: `userMoves <= optimalMoves`
  /// - 2 Stars: `userMoves <= optimalMoves + 3`
  /// - 1 Star: `userMoves > optimalMoves + 3`
  static int calculateStars({
    required int userMoves,
    required int optimalMoves,
  }) {
    if (userMoves <= optimalMoves) {
      return 3;
    }
    if (userMoves <= optimalMoves + 3) {
      return 2;
    }
    return 1;
  }

  /// Generates all valid single-vehicle sliding moves from [state].
  /// Moving 1 or more cells along the vehicle's axis counts as 1 move.
  static List<Move> generateAllValidMoves(BoardState state) {
    final List<Move> moves = [];

    for (final vehicle in state.vehicles) {
      final bounds = getMovementBounds(state, vehicle.id);
      if (vehicle.isHorizontal) {
        // Prefer rightward moves for target car 'A' first, or iterate all valid cols
        for (int c = bounds.maxCol; c >= bounds.minCol; c--) {
          if (c == vehicle.col) continue;
          moves.add(
            Move(
              vehicleId: vehicle.id,
              fromRow: vehicle.row,
              fromCol: vehicle.col,
              toRow: vehicle.row,
              toCol: c,
            ),
          );
        }
      } else {
        for (int r = bounds.minRow; r <= bounds.maxRow; r++) {
          if (r == vehicle.row) continue;
          moves.add(
            Move(
              vehicleId: vehicle.id,
              fromRow: vehicle.row,
              fromCol: vehicle.col,
              toRow: r,
              toCol: vehicle.col,
            ),
          );
        }
      }
    }

    return moves;
  }
}
