import '../../domain/entities/vehicle.dart';

class VehicleModel extends Vehicle {
  const VehicleModel({
    required super.id,
    required super.row,
    required super.col,
    required super.length,
    required super.isHorizontal,
  });

  factory VehicleModel.fromEntity(Vehicle vehicle) {
    return VehicleModel(
      id: vehicle.id,
      row: vehicle.row,
      col: vehicle.col,
      length: vehicle.length,
      isHorizontal: vehicle.isHorizontal,
    );
  }

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'] as String,
      row: json['row'] as int,
      col: json['col'] as int,
      length: json['length'] as int,
      isHorizontal: json['is_horizontal'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'row': row,
      'col': col,
      'length': length,
      'is_horizontal': isHorizontal,
    };
  }
}
