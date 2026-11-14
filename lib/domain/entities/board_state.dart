import 'package:equatable/equatable.dart';
import '../../core/constants/app_constants.dart';
import 'move.dart';
import 'vehicle.dart';

class BoardState extends Equatable {
  final List<Vehicle> vehicles;
  final int moveCount;
  final int optimalMoves;
  final List<Move> moveHistory;

  const BoardState({
    required this.vehicles,
    this.moveCount = 0,
    this.optimalMoves = 0,
    this.moveHistory = const [],
  });

  Vehicle? getVehicleById(String id) {
    for (final v in vehicles) {
      if (v.id == id) return v;
    }
    return null;
  }

  Vehicle? get targetVehicle => getVehicleById(AppConstants.targetVehicleId);

  bool get isWon {
    final target = targetVehicle;
    if (target == null) return false;
    return target.isHorizontal &&
        target.row == AppConstants.exitRow &&
        target.col == AppConstants.targetWinCol;
  }

  bool get canUndo => moveHistory.isNotEmpty;

  /// Converts the current board state to its canonical 36-character string.
  String toBoardString() {
    final grid = List<String>.filled(
      AppConstants.boardStringLength,
      AppConstants.emptyCellChar,
    );
    for (final v in vehicles) {
      for (int i = 0; i < v.length; i++) {
        final r = v.isHorizontal ? v.row : v.row + i;
        final c = v.isHorizontal ? v.col + i : v.col;
        if (r >= 0 &&
            r < AppConstants.gridSize &&
            c >= 0 &&
            c < AppConstants.gridSize) {
          grid[r * AppConstants.gridSize + c] = v.id;
        }
      }
    }
    return grid.join();
  }

  BoardState copyWith({
    List<Vehicle>? vehicles,
    int? moveCount,
    int? optimalMoves,
    List<Move>? moveHistory,
  }) {
    return BoardState(
      vehicles: vehicles ?? this.vehicles,
      moveCount: moveCount ?? this.moveCount,
      optimalMoves: optimalMoves ?? this.optimalMoves,
      moveHistory: moveHistory ?? this.moveHistory,
    );
  }

  @override
  List<Object?> get props => [vehicles, moveCount, optimalMoves, moveHistory];
}
