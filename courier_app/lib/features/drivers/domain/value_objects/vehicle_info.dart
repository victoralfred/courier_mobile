import 'package:equatable/equatable.dart';
import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:delivery_app/core/error/exceptions.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/vehicle_type.dart';

/// VehicleInfo value object for Nigerian courier driver vehicles
///
/// Immutable value object that ensures:
/// - Plate number is not empty
/// - Vehicle make and model are not empty
/// - Year is between 1990 and next year (for new models)
/// - Color is not empty
///
/// Usage:
/// ```dart
/// final vehicle = VehicleInfo(
///   plate: 'ABC-123-XY',
///   type: VehicleType.car,
///   make: 'Toyota',
///   model: 'Corolla',
///   year: 2020,
///   color: 'Silver',
/// );
/// ```
class VehicleInfo extends Equatable {
  final String plate;
  final VehicleType type;
  final String make;
  final String model;
  final int year;
  final String color;

  const VehicleInfo._({
    required this.plate,
    required this.type,
    required this.make,
    required this.model,
    required this.year,
    required this.color,
  });

  /// Creates a VehicleInfo with validation
  ///
  /// Throws [ValidationException] if:
  /// - plate is empty or whitespace
  /// - make is empty or whitespace
  /// - model is empty or whitespace
  /// - color is empty or whitespace
  /// - year is < 1990 or > next year
  factory VehicleInfo({
    required String plate,
    required VehicleType type,
    required String make,
    required String model,
    required int year,
    required String color,
  }) {
    // Trim whitespace
    final trimmedPlate = plate.trim();
    final trimmedMake = make.trim();
    final trimmedModel = model.trim();
    final trimmedColor = color.trim();

    // Validate plate
    if (trimmedPlate.isEmpty) {
      throw const ValidationException(
        message: AppStrings.errorVehicleEmptyPlate,
        fieldErrors: {'plate': AppStrings.errorVehicleEmptyPlate},
      );
    }

    // Validate make
    if (trimmedMake.isEmpty) {
      throw const ValidationException(
        message: AppStrings.errorVehicleEmptyMake,
        fieldErrors: {'make': AppStrings.errorVehicleEmptyMake},
      );
    }

    // Validate model
    if (trimmedModel.isEmpty) {
      throw const ValidationException(
        message: AppStrings.errorVehicleEmptyModel,
        fieldErrors: {'model': AppStrings.errorVehicleEmptyModel},
      );
    }

    // Validate color
    if (trimmedColor.isEmpty) {
      throw const ValidationException(
        message: AppStrings.errorVehicleEmptyColor,
        fieldErrors: {'color': AppStrings.errorVehicleEmptyColor},
      );
    }

    // Validate year (1990 to next year for new models)
    final currentYear = DateTime.now().year;
    if (year < 1990 || year > currentYear + 1) {
      throw const ValidationException(
        message: AppStrings.errorVehicleInvalidYear,
        fieldErrors: {'year': AppStrings.errorVehicleInvalidYear},
      );
    }

    return VehicleInfo._(
      plate: trimmedPlate,
      type: type,
      make: trimmedMake,
      model: trimmedModel,
      year: year,
      color: trimmedColor,
    );
  }

  /// Get formatted display name
  ///
  /// Format: "{year} {make} {model} ({color})"
  /// Example: "2020 Toyota Corolla (Silver)"
  String get displayName => '$year $make $model ($color)';

  /// Create a copy with optional new values
  VehicleInfo copyWith({
    String? plate,
    VehicleType? type,
    String? make,
    String? model,
    int? year,
    String? color,
  }) =>
      VehicleInfo(
        plate: plate ?? this.plate,
        type: type ?? this.type,
        make: make ?? this.make,
        model: model ?? this.model,
        year: year ?? this.year,
        color: color ?? this.color,
      );

  @override
  List<Object?> get props => [plate, type, make, model, year, color];

  @override
  String toString() => 'VehicleInfo(plate: $plate, $displayName)';
}
