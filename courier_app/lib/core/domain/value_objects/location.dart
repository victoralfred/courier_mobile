import 'package:equatable/equatable.dart';
import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:delivery_app/core/error/exceptions.dart';
import 'package:delivery_app/core/domain/value_objects/coordinate.dart';
import 'package:delivery_app/core/domain/value_objects/distance.dart';

/// Location value object for Nigerian addresses
///
/// Immutable value object that ensures:
/// - Address, city, and state are not empty
/// - Valid coordinate within Nigeria bounds
/// - Country is always "Nigeria"
///
/// Usage:
/// ```dart
/// final location = Location(
///   address: '23 Marina Road, Lagos Island',
///   coordinate: Coordinate(latitude: 6.5244, longitude: 3.3792),
///   city: 'Lagos',
///   state: 'Lagos',
///   postcode: '101001',
/// );
/// print(location.fullAddress); // "23 Marina Road, Lagos Island, Lagos, Lagos 101001, Nigeria"
/// ```
class Location extends Equatable {
  final String address;
  final Coordinate coordinate;
  final String city;
  final String state;
  final String country;
  final String? postcode;

  const Location._({
    required this.address,
    required this.coordinate,
    required this.city,
    required this.state,
    required this.country,
    this.postcode,
  });

  /// Creates a Location with Nigerian address format
  ///
  /// Throws [ValidationException] if:
  /// - Address is empty
  /// - City is empty
  /// - State is empty
  factory Location({
    required String address,
    required Coordinate coordinate,
    required String city,
    required String state,
    String? postcode,
  }) {
    // Trim whitespace
    final trimmedAddress = address.trim();
    final trimmedCity = city.trim();
    final trimmedState = state.trim();
    final trimmedPostcode = postcode?.trim();

    // Validate address
    if (trimmedAddress.isEmpty) {
      throw const ValidationException(
        message: AppStrings.errorLocationEmptyAddress,
        fieldErrors: {'address': AppStrings.errorLocationEmptyAddress},
      );
    }

    // Validate city
    if (trimmedCity.isEmpty) {
      throw const ValidationException(
        message: AppStrings.errorLocationEmptyCity,
        fieldErrors: {'city': AppStrings.errorLocationEmptyCity},
      );
    }

    // Validate state
    if (trimmedState.isEmpty) {
      throw const ValidationException(
        message: AppStrings.errorLocationEmptyState,
        fieldErrors: {'state': AppStrings.errorLocationEmptyState},
      );
    }

    return Location._(
      address: trimmedAddress,
      coordinate: coordinate,
      city: trimmedCity,
      state: trimmedState,
      country: 'Nigeria',
      postcode: trimmedPostcode,
    );
  }

  /// Get full formatted address
  ///
  /// Format: address, city, state [postcode], country
  /// Example: "23 Marina Road, Lagos, Lagos 101001, Nigeria"
  String get fullAddress {
    final buffer = StringBuffer();
    buffer.write(address);
    buffer.write(', $city');
    buffer.write(', $state');

    if (postcode != null && postcode!.isNotEmpty) {
      buffer.write(' $postcode');
    }

    buffer.write(', $country');

    return buffer.toString();
  }

  /// Calculate distance to another location
  Distance distanceTo(Location other) =>
      coordinate.distanceTo(other.coordinate);

  /// Create a copy with optional new values
  Location copyWith({
    String? address,
    Coordinate? coordinate,
    String? city,
    String? state,
    String? postcode,
  }) =>
      Location(
        address: address ?? this.address,
        coordinate: coordinate ?? this.coordinate,
        city: city ?? this.city,
        state: state ?? this.state,
        postcode: postcode ?? this.postcode,
      );

  @override
  List<Object?> get props =>
      [address, coordinate, city, state, country, postcode];

  @override
  String toString() => fullAddress;
}
