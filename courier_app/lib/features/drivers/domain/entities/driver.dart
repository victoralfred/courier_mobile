import 'package:equatable/equatable.dart';
import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:delivery_app/core/domain/value_objects/coordinate.dart';
import 'package:delivery_app/core/error/exceptions.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/availability_status.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/driver_status.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/vehicle_info.dart';

/// Driver entity for Nigerian courier delivery service
///
/// Represents a delivery driver with personal information, vehicle details,
/// verification status, and real-time availability.
///
/// Usage:
/// ```dart
/// final driver = Driver(
///   id: 'driver-123',
///   userId: 'user-456',
///   firstName: 'John',
///   lastName: 'Doe',
///   email: 'john.doe@example.com',
///   phone: '+2348012345678',
///   licenseNumber: 'LAG-12345-AB',
///   vehicleInfo: vehicleInfo,
///   status: DriverStatus.approved,
///   availability: AvailabilityStatus.available,
///   rating: 4.5,
///   totalRatings: 100,
/// );
/// ```
class Driver extends Equatable {
  final String id;
  final String userId;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String licenseNumber;
  final VehicleInfo vehicleInfo;
  final DriverStatus status;
  final AvailabilityStatus availability;
  final Coordinate? currentLocation;
  final DateTime? lastLocationUpdate;
  final double rating;
  final int totalRatings;

  const Driver._({
    required this.id,
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.licenseNumber,
    required this.vehicleInfo,
    required this.status,
    required this.availability,
    this.currentLocation,
    this.lastLocationUpdate,
    required this.rating,
    required this.totalRatings,
  });

  /// Creates a Driver with validation
  ///
  /// Throws [ValidationException] if any field is invalid
  factory Driver({
    required String id,
    required String userId,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String licenseNumber,
    required VehicleInfo vehicleInfo,
    required DriverStatus status,
    required AvailabilityStatus availability,
    Coordinate? currentLocation,
    DateTime? lastLocationUpdate,
    required double rating,
    required int totalRatings,
  }) {
    // Trim whitespace
    final trimmedFirstName = firstName.trim();
    final trimmedLastName = lastName.trim();
    final trimmedEmail = email.trim();
    final trimmedPhone = phone.trim();
    final trimmedLicenseNumber = licenseNumber.trim();

    // Validate firstName
    if (trimmedFirstName.isEmpty) {
      throw const ValidationException(
        message: AppStrings.errorDriverEmptyFirstName,
        fieldErrors: {'firstName': AppStrings.errorDriverEmptyFirstName},
      );
    }

    // Validate lastName
    if (trimmedLastName.isEmpty) {
      throw const ValidationException(
        message: AppStrings.errorDriverEmptyLastName,
        fieldErrors: {'lastName': AppStrings.errorDriverEmptyLastName},
      );
    }

    // Validate email
    if (trimmedEmail.isEmpty) {
      throw const ValidationException(
        message: AppStrings.errorDriverEmptyEmail,
        fieldErrors: {'email': AppStrings.errorDriverEmptyEmail},
      );
    }

    // Basic email format validation
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(trimmedEmail)) {
      throw const ValidationException(
        message: AppStrings.errorDriverInvalidEmail,
        fieldErrors: {'email': AppStrings.errorDriverInvalidEmail},
      );
    }

    // Validate phone
    if (trimmedPhone.isEmpty) {
      throw const ValidationException(
        message: AppStrings.errorDriverEmptyPhone,
        fieldErrors: {'phone': AppStrings.errorDriverEmptyPhone},
      );
    }

    // Validate licenseNumber
    if (trimmedLicenseNumber.isEmpty) {
      throw const ValidationException(
        message: AppStrings.errorDriverEmptyLicenseNumber,
        fieldErrors: {'licenseNumber': AppStrings.errorDriverEmptyLicenseNumber},
      );
    }

    // Validate rating (0-5 range)
    if (rating < 0 || rating > 5) {
      throw const ValidationException(
        message: AppStrings.errorDriverInvalidRating,
        fieldErrors: {'rating': AppStrings.errorDriverInvalidRating},
      );
    }

    return Driver._(
      id: id,
      userId: userId,
      firstName: trimmedFirstName,
      lastName: trimmedLastName,
      email: trimmedEmail,
      phone: trimmedPhone,
      licenseNumber: trimmedLicenseNumber,
      vehicleInfo: vehicleInfo,
      status: status,
      availability: availability,
      currentLocation: currentLocation,
      lastLocationUpdate: lastLocationUpdate,
      rating: rating,
      totalRatings: totalRatings,
    );
  }

  /// Get full name (firstName + lastName)
  String get fullName => '$firstName $lastName';

  /// Check if driver is pending verification
  bool get isPending => status == DriverStatus.pending;

  /// Check if driver is approved
  bool get isApproved => status == DriverStatus.approved;

  /// Check if driver application is rejected
  bool get isRejected => status == DriverStatus.rejected;

  /// Check if driver is suspended
  bool get isSuspended => status == DriverStatus.suspended;

  /// Check if driver is online (available or busy)
  bool get isOnline => availability.isOnline;

  /// Check if driver can accept new orders
  bool get canAcceptOrders =>
      status == DriverStatus.approved && availability.canAcceptOrders;

  /// Check if driver has current location set
  bool get hasLocation => currentLocation != null;

  /// Create a copy with optional new values
  Driver copyWith({
    String? id,
    String? userId,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? licenseNumber,
    VehicleInfo? vehicleInfo,
    DriverStatus? status,
    AvailabilityStatus? availability,
    Coordinate? currentLocation,
    DateTime? lastLocationUpdate,
    double? rating,
    int? totalRatings,
  }) =>
      Driver(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        licenseNumber: licenseNumber ?? this.licenseNumber,
        vehicleInfo: vehicleInfo ?? this.vehicleInfo,
        status: status ?? this.status,
        availability: availability ?? this.availability,
        currentLocation: currentLocation ?? this.currentLocation,
        lastLocationUpdate: lastLocationUpdate ?? this.lastLocationUpdate,
        rating: rating ?? this.rating,
        totalRatings: totalRatings ?? this.totalRatings,
      );

  @override
  List<Object?> get props => [
        id,
        userId,
        firstName,
        lastName,
        email,
        phone,
        licenseNumber,
        vehicleInfo,
        status,
        availability,
        currentLocation,
        lastLocationUpdate,
        rating,
        totalRatings,
      ];

  @override
  String toString() => 'Driver(id: $id, name: $fullName, '
      'status: ${status.displayName}, availability: ${availability.displayName})';
}
