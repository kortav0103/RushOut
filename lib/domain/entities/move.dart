import 'package:equatable/equatable.dart';

class Move extends Equatable {
  final String vehicleId;
  final int fromRow;
  final int fromCol;
  final int toRow;
  final int toCol;

  const Move({
    required this.vehicleId,
    required this.fromRow,
    required this.fromCol,
    required this.toRow,
    required this.toCol,
  });

  const Move.positional(
    this.vehicleId,
    this.fromRow,
    this.fromCol,
    this.toRow,
    this.toCol,
  );

  int get deltaRow => toRow - fromRow;
  int get deltaCol => toCol - fromCol;
  int get cellsMoved => deltaRow.abs() + deltaCol.abs();

  bool get isActualMove => fromRow != toRow || fromCol != toCol;

  Move get reversed => Move(
        vehicleId: vehicleId,
        fromRow: toRow,
        fromCol: toCol,
        toRow: fromRow,
        toCol: fromCol,
      );

  @override
  List<Object?> get props => [vehicleId, fromRow, fromCol, toRow, toCol];

  @override
  String toString() =>
      'Move($vehicleId: ($fromRow, $fromCol) -> ($toRow, $toCol))';
}
