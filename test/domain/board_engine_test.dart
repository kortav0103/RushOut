import 'package:flutter_test/flutter_test.dart';
import 'package:rush_out/core/utils/level_parser.dart';
import 'package:rush_out/domain/engine/board_engine.dart';
import 'package:rush_out/domain/entities/board_state.dart';
import 'package:rush_out/domain/entities/vehicle.dart';

void main() {
  group('BoardEngine Tests', () {
    // Board layout:
    // Row 0: o o B o o o  (B: vert len 2 at (0,2)..(1,2))
    // Row 1: o o B o o o
    // Row 2: A A o C o o  (A: horiz len 2 at (2,0)..(2,1); C: vert len 3 at (2,3)..(4,3))
    // Row 3: o o o C o o
    // Row 4: o D D C o o  (D: horiz len 2 at (4,1)..(4,2))
    // Row 5: o o o o o o
    late BoardState initialState;

    setUp(() {
      initialState = const BoardState(
        optimalMoves: 3,
        vehicles: [
          Vehicle(id: 'A', row: 2, col: 0, length: 2, isHorizontal: true),
          Vehicle(id: 'B', row: 0, col: 2, length: 2, isHorizontal: false),
          Vehicle(id: 'C', row: 2, col: 3, length: 3, isHorizontal: false),
          Vehicle(id: 'D', row: 4, col: 1, length: 2, isHorizontal: true),
        ],
      );
    });

    test('enforces horizontal and vertical axis locking', () {
      // Horizontal car A cannot move vertically (row != 2)
      expect(
        BoardEngine.canMoveTo(initialState, 'A', toRow: 1, toCol: 0),
        isFalse,
      );
      final afterInvalidVert = BoardEngine.moveVehicle(
        initialState,
        'A',
        toRow: 1,
        toCol: 0,
      );
      expect(afterInvalidVert, equals(initialState));

      // Vertical car B cannot move horizontally (col != 2)
      expect(
        BoardEngine.canMoveTo(initialState, 'B', toRow: 0, toCol: 3),
        isFalse,
      );
      final afterInvalidHoriz = BoardEngine.moveVehicle(
        initialState,
        'B',
        toRow: 0,
        toCol: 3,
      );
      expect(afterInvalidHoriz, equals(initialState));
    });

    test('detects collisions against grid boundaries and adjacent vehicles', () {
      // Target car A at (2,0) len 2 is blocked on the right at (2,3) by C.
      // So A can only occupy col 0 or col 1 (occupying (2,1)..(2,2)).
      final boundsA = BoardEngine.getMovementBounds(initialState, 'A');
      expect(boundsA.minRow, 2);
      expect(boundsA.maxRow, 2);
      expect(boundsA.minCol, 0);
      expect(boundsA.maxCol, 1);

      // Attempting to jump A over C to col 4 must be rejected
      expect(
        BoardEngine.canMoveTo(initialState, 'A', toRow: 2, toCol: 4),
        isFalse,
      );

      // Vertical car B at (0,2) len 2 is blocked below at (4,2) by D, so B can move down to row 2 (occupying (2,2)..(3,2))
      final boundsB = BoardEngine.getMovementBounds(initialState, 'B');
      expect(boundsB.minRow, 0);
      expect(boundsB.maxRow, 2);
      expect(boundsB.minCol, 2);
      expect(boundsB.maxCol, 2);

      // Vertical truck C at (2,3) len 3 can slide up to row 0 or down to row 3
      final boundsC = BoardEngine.getMovementBounds(initialState, 'C');
      expect(boundsC.minRow, 0);
      expect(boundsC.maxRow, 3);
      expect(boundsC.minCol, 3);
      expect(boundsC.maxCol, 3);
    });

    test('snaps dragged vehicle to nearest valid integer cell and updates undo stack', () {
      // Drag A slightly to the right (col 0.8 -> snaps to col 1)
      final state1 = BoardEngine.snapVehicle(
        initialState,
        'A',
        draggedRow: 2.0,
        draggedCol: 0.8,
      );
      expect(state1.getVehicleById('A')!.col, 1);
      expect(state1.moveCount, 1);
      expect(state1.moveHistory.length, 1);
      expect(state1.moveHistory.first.vehicleId, 'A');
      expect(state1.moveHistory.first.fromCol, 0);
      expect(state1.moveHistory.first.toCol, 1);

      // Dragging within the same cell (1.2 -> snaps to 1) does not increment moveCount
      final stateSame = BoardEngine.snapVehicle(
        state1,
        'A',
        draggedRow: 2.0,
        draggedCol: 1.2,
      );
      expect(stateSame.moveCount, 1);
      expect(stateSame.moveHistory.length, 1);

      // Move C down to row 3
      final state2 = BoardEngine.moveVehicle(state1, 'C', toRow: 3, toCol: 3);
      expect(state2.moveCount, 2);
      expect(state2.moveHistory.length, 2);

      // Undo last move (C returns to row 2)
      final afterUndo1 = BoardEngine.undo(state2);
      expect(afterUndo1.getVehicleById('C')!.row, 2);
      expect(afterUndo1.moveCount, 1);
      expect(afterUndo1.moveHistory.length, 1);

      // Undo first move (A returns to col 0)
      final afterUndo2 = BoardEngine.undo(afterUndo1);
      expect(afterUndo2.getVehicleById('A')!.col, 0);
      expect(afterUndo2.moveCount, 0);
      expect(afterUndo2.canUndo, isFalse);
    });

    test('detects win condition when target A reaches (row: 2, col: 4) and calculates stars', () {
      expect(BoardEngine.isWinningState(initialState), isFalse);

      // Slide C up to (0,3) so row 2 col 3 becomes free? Wait: C has length 3, so at row 0 it occupies rows 0, 1, 2!
      // Instead, slide D left to (4,0) so (4,2) is free, or slide C: wait C is at col 3 (rows 2,3,4).
      // Let's test on a board where C is length 2 at (1,3)..(2,3):
      final board = LevelParser.parseToBoardState(
        'oooooo'
        'oooCoo'
        'AAoCoo'
        'oooooo'
        'oooooo'
        'oooooo',
        optimalMoves: 2,
      );

      expect(board.isWon, isFalse);

      // Move 1: Slide C down to (3,3)
      final afterMove1 = BoardEngine.moveVehicle(board, 'C', toRow: 3, toCol: 3);
      expect(afterMove1.isWon, isFalse);

      // Move 2: Slide A right to (2,4)
      final afterMove2 = BoardEngine.moveVehicle(
        afterMove1,
        'A',
        toRow: 2,
        toCol: 4,
      );
      expect(afterMove2.isWon, isTrue);
      expect(BoardEngine.isWinningState(afterMove2), isTrue);
      expect(afterMove2.moveCount, 2);

      // Star calculation checks:
      expect(BoardEngine.calculateStars(userMoves: 2, optimalMoves: 2), 3);
      expect(BoardEngine.calculateStars(userMoves: 4, optimalMoves: 2), 2);
      expect(BoardEngine.calculateStars(userMoves: 5, optimalMoves: 2), 2);
      expect(BoardEngine.calculateStars(userMoves: 6, optimalMoves: 2), 1);
    });
  });
}
