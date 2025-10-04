import 'package:equatable/equatable.dart';
import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:delivery_app/core/error/exceptions.dart';

/// Distance value object for Nigeria courier logistics (metric system)
///
/// Immutable value object that ensures:
/// - Distance is always non-negative
/// - Distance is a valid number (not NaN or infinity)
/// - Uses metric system (meters as base unit)
///
/// Usage:
/// ```dart
/// final distance = Distance.fromKilometers(10.5);
/// print(distance.inKilometers); // 10.5
/// print(distance.inMeters); // 10500
/// ```
class Distance extends Equatable implements Comparable<Distance> {
  /// Distance in meters (base unit)
  final double meters;

  const Distance._({required this.meters});

  /// Creates a Distance from meters
  factory Distance.fromMeters(double meters) {
    if (meters < 0) {
      throw const ValidationException(
        message: AppStrings.errorDistanceNegative,
        fieldErrors: {'meters': AppStrings.errorDistanceNegative},
      );
    }

    if (meters.isNaN || meters.isInfinite) {
      throw const ValidationException(
        message: AppStrings.errorDistanceInvalid,
        fieldErrors: {'meters': AppStrings.errorDistanceInvalid},
      );
    }

    return Distance._(meters: meters);
  }

  /// Creates a Distance from kilometers
  factory Distance.fromKilometers(double kilometers) =>
      Distance.fromMeters(kilometers * 1000);

  /// Get distance in meters
  double get inMeters => meters;

  /// Get distance in kilometers
  double get inKilometers => meters / 1000;

  /// Check if distance is zero
  bool get isZero => meters == 0;

  /// Format distance with appropriate unit
  String get formatted {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  @override
  int compareTo(Distance other) => meters.compareTo(other.meters);

  /// Greater than comparison
  bool operator >(Distance other) => meters > other.meters;

  /// Less than comparison
  bool operator <(Distance other) => meters < other.meters;

  /// Greater than or equal comparison
  bool operator >=(Distance other) => meters >= other.meters;

  /// Less than or equal comparison
  bool operator <=(Distance other) => meters <= other.meters;

  /// Add two distances
  Distance operator +(Distance other) =>
      Distance.fromMeters(meters + other.meters);

  /// Subtract two distances
  Distance operator -(Distance other) =>
      Distance.fromMeters(meters - other.meters);

  @override
  List<Object?> get props => [meters];

  @override
  String toString() => formatted;
}
