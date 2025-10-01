import 'dart:math' as math;
import 'package:equatable/equatable.dart';
import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:delivery_app/core/error/exceptions.dart';
import 'package:delivery_app/core/domain/value_objects/distance.dart';

/// Coordinate value object for Nigeria geographic locations
///
/// Immutable value object that ensures:
/// - Latitude and longitude are valid numbers
/// - Coordinates are within Nigeria geographic bounds
/// - Latitude: 4°N to 14°N (approximate Nigeria bounds)
/// - Longitude: 3°E to 15°E (approximate Nigeria bounds)
///
/// Usage:
/// ```dart
/// final lagos = Coordinate(latitude: 6.5244, longitude: 3.3792);
/// final abuja = Coordinate(latitude: 9.0765, longitude: 7.3986);
/// final distance = lagos.distanceTo(abuja);
/// print(distance.inKilometers); // ~481 km
/// ```
class Coordinate extends Equatable {
  /// Nigeria geographic bounds (approximate)
  static const double minLatitude = 4.0; // Southernmost point (~4°N)
  static const double maxLatitude = 14.0; // Northernmost point (~14°N)
  static const double minLongitude = 3.0; // Westernmost point (~3°E)
  static const double maxLongitude = 15.0; // Easternmost point (~15°E)

  final double latitude;
  final double longitude;

  const Coordinate._({
    required this.latitude,
    required this.longitude,
  });

  /// Creates a Coordinate with validation for Nigeria bounds
  ///
  /// Throws [ValidationException] if:
  /// - Latitude or longitude is NaN or infinite
  /// - Coordinates are outside Nigeria geographic bounds
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

    // Validate Nigeria bounds - latitude
    if (latitude < minLatitude || latitude > maxLatitude) {
      throw const ValidationException(
        message: AppStrings.errorCoordinateLatitudeRange,
        fieldErrors: {'latitude': AppStrings.errorCoordinateLatitudeRange},
      );
    }

    // Validate Nigeria bounds - longitude
    if (longitude < minLongitude || longitude > maxLongitude) {
      throw const ValidationException(
        message: AppStrings.errorCoordinateLongitudeRange,
        fieldErrors: {'longitude': AppStrings.errorCoordinateLongitudeRange},
      );
    }

    return Coordinate._(latitude: latitude, longitude: longitude);
  }

  /// Check if coordinate is within Nigeria bounds
  bool get isWithinNigeria =>
      latitude >= minLatitude &&
      latitude <= maxLatitude &&
      longitude >= minLongitude &&
      longitude <= maxLongitude;

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
