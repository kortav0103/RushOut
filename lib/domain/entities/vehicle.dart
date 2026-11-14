import 'package:equatable/equatable.dart';
import '../../core/constants/app_constants.dart';

class Vehicle extends Equatable {
  final String id;
  final int row;
  final int col;
  final int length;
  final bool isHorizontal;

  const Vehicle({
    required this.id,
    required this.row,
    required this.col,
    required this.length,
    required this.isHorizontal,
  }) : assert(length == 2 || length == 3, 'Vehicle length must be 2 or 3');

  bool get isTarget => id == AppConstants.targetVehicleId;

  int get endRow => isHorizontal ? row : row + length - 1;

  int get endCol => isHorizontal ? col + length - 1 : col;

  bool occupies(int r, int c) {
    if (isHorizontal) {
      return r == row && c >= col && c < col + length;
    } else {
      return c == col && r >= row && r < row + length;
    }
  }

  Vehicle copyWith({
    String? id,
    int? row,
    int? col,
    int? length,
    bool? isHorizontal,
  }) {
    return Vehicle(
      id: id ?? this.id,
      row: row ?? this.row,
      col: col ?? this.col,
      length: length ?? this.length,
      isHorizontal: isHorizontal ?? this.isHorizontal,
    );
  }

  @override
  List<Object?> get props => [id, row, col, length, isHorizontal];
}
