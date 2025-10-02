import 'dart:math' as math;
import 'package:equatable/equatable.dart';
import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:delivery_app/core/error/exceptions.dart';
import 'package:delivery_app/core/domain/value_objects/distance.dart';

/// Coordinate value object for geographic locations
///
/// Immutable value object that ensures:
/// - Latitude and longitude are valid numbers
/// - Latitude: -90° to 90° (standard geographic bounds)
/// - Longitude: -180° to 180° (standard geographic bounds)
///
/// Usage:
/// ```dart
/// final lagos = Coordinate(latitude: 6.5244, longitude: 3.3792);
/// final newYork = Coordinate(latitude: 40.7128, longitude: -74.0060);
/// final distance = lagos.distanceTo(newYork);
/// print(distance.inKilometers); // Distance in km
/// ```
class Coordinate extends Equatable {
  /// Standard geographic bounds
  static const double minLatitude = -90.0;
  static const double maxLatitude = 90.0;
  static const double minLongitude = -180.0;
  static const double maxLongitude = 180.0;

  final double latitude;
  final double longitude;

  const Coordinate._({
    required this.latitude,
    required this.longitude,
  });

  /// Creates a Coordinate with validation for global bounds
  ///
  /// Throws [ValidationException] if:
  /// - Latitude or longitude is NaN or infinite
  /// - Coordinates are outside standard geographic bounds
  factory Coordinate({
    required double latitude,
    required double longitude,
  }) {
    // Validate latitude
    if (latitude.isNaN || latitude.isInfinite) {
      throw const ValidationException(
        message: AppStrings.errorCoordinateInvalidLatitude,
        fieldErrors: {'latitude': AppStrings.errorCoordinateInvalidLatitude},
      );
    }

    // Validate longitude
    if (longitude.isNaN || longitude.isInfinite) {
      throw const ValidationException(
        message: AppStrings.errorCoordinateInvalidLongitude,
        fieldErrors: {'longitude': AppStrings.errorCoordinateInvalidLongitude},
      );
    }

    // Validate global bounds - latitude
    if (latitude < minLatitude || latitude > maxLatitude) {
      throw const ValidationException(
        message: 'Latitude must be between -90° and 90°',
        fieldErrors: {'latitude': 'Latitude must be between -90° and 90°'},
      );
    }

    // Validate global bounds - longitude
    if (longitude < minLongitude || longitude > maxLongitude) {
      throw const ValidationException(
        message: 'Longitude must be between -180° and 180°',
        fieldErrors: {'longitude': 'Longitude must be between -180° and 180°'},
      );
    }

    return Coordinate._(latitude: latitude, longitude: longitude);
  }

  /// Check if coordinate is valid
  bool get isValid =>
      latitude >= minLatitude &&
      latitude <= maxLatitude &&
      longitude >= minLongitude &&
      longitude <= maxLongitude;

  /// Check if coordinate is within Nigeria's geographic bounds
  ///
  /// Nigeria's approximate boundaries:
  /// - Latitude: 4°N to 14°N
  /// - Longitude: 3°E to 15°E
  bool get isWithinNigeria =>
      latitude >= 4.0 &&
      latitude <= 14.0 &&
      longitude >= 3.0 &&
      longitude <= 15.0;

  /// Calculate distance to another coordinate using Haversine formula
  ///
  /// Returns distance in Distance value object
  Distance distanceTo(Coordinate other) {
    const earthRadiusKm = 6371.0; // Earth's radius in kilometers

    // Convert degrees to radians
    final lat1Rad = _degreesToRadians(latitude);
    final lat2Rad = _degreesToRadians(other.latitude);
    final deltaLatRad = _degreesToRadians(other.latitude - latitude);
    final deltaLonRad = _degreesToRadians(other.longitude - longitude);

    // Haversine formula
    final a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLonRad / 2) *
            math.sin(deltaLonRad / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final distanceKm = earthRadiusKm * c;

    return Distance.fromKilometers(distanceKm);
  }

  /// Convert degrees to radians
  double _degreesToRadians(double degrees) => degrees * math.pi / 180.0;

  /// Create a copy with optional new coordinates
  Coordinate copyWith({
    double? latitude,
    double? longitude,
  }) =>
      Coordinate(
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
      );

  @override
  List<Object?> get props => [latitude, longitude];

  @override
  String toString() => '$latitude, $longitude';
}
