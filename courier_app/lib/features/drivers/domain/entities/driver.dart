import 'package:equatable/equatable.dart';
import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:delivery_app/core/domain/value_objects/coordinate.dart';
import 'package:delivery_app/core/error/exceptions.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/availability_status.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/driver_status.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/vehicle_info.dart';

/// [Driver] - Core domain entity representing a delivery driver in the courier app
///
/// **What it does:**
/// - Represents verified delivery drivers with complete profile information
/// - Enforces business rules via validation (name length, email format, rating range)
/// - Tracks driver verification status (pending, approved, rejected, suspended)
/// - Manages real-time availability for order assignment
/// - Maintains driver location for delivery tracking
/// - Stores driver rating and performance metrics
/// - Uses value objects for type safety (VehicleInfo, Coordinate)
/// - Immutable entity with copyWith pattern
///
/// **Why it exists:**
/// - Central driver identity representation across the app
/// - Enforces data integrity through validation
/// - Separates domain logic from presentation/infrastructure
/// - Enables driver verification workflow
/// - Type-safe driver data (no invalid emails, ratings, etc.)
/// - Clean Architecture domain layer entity
/// - Supports real-time driver tracking and order assignment
///
/// **Entity Validation Rules:**
/// - **First Name**: Non-empty, trimmed
/// - **Last Name**: Non-empty, trimmed
/// - **Email**: Non-empty, valid email format (regex validated)
/// - **Phone**: Non-empty, trimmed
/// - **License Number**: Non-empty, trimmed
/// - **Rating**: 0-5 range (inclusive)
/// - **Status**: One of (pending, approved, rejected, suspended)
/// - **Availability**: One of (offline, available, busy)
///
/// **Business Logic:**
/// - Only approved drivers can accept orders
/// - Drivers must be available (not busy/offline) to accept new orders
/// - Rejected drivers have rejection reason tracked
/// - Suspended drivers have suspension reason and expiration date
/// - Status changes are timestamped for audit trail
///
/// **Usage Example:**
/// ```dart
/// // Create new driver (onboarding)
/// final driver = Driver(
///   id: 'driver-123',
///   userId: 'user-456',
///   firstName: 'Chidi',
///   lastName: 'Okonkwo',
///   email: 'chidi@example.com',
///   phone: '+2348012345678',
///   licenseNumber: 'LAG-12345-AB',
///   vehicleInfo: VehicleInfo(
///     plate: 'ABC-123-XY',
///     type: VehicleType.motorcycle,
///     make: 'Honda',
///     model: 'CBR',
///     year: 2020,
///     color: 'Red',
///   ),
///   status: DriverStatus.pending,
///   availability: AvailabilityStatus.offline,
///   rating: 0.0,
///   totalRatings: 0,
/// );
///
/// // Check if driver can accept orders
/// if (driver.canAcceptOrders) {
///   print('Driver ${driver.fullName} can accept orders');
/// }
///
/// // Update driver status (admin approval)
/// final approvedDriver = driver.copyWith(
///   status: DriverStatus.approved,
///   statusUpdatedAt: DateTime.now(),
/// );
///
/// // Update availability (driver goes online)
/// final onlineDriver = approvedDriver.copyWith(
///   availability: AvailabilityStatus.available,
///   currentLocation: Coordinate(latitude: 6.5244, longitude: 3.3792), // Lagos
///   lastLocationUpdate: DateTime.now(),
/// );
///
/// // Suspend driver with reason
/// final suspendedDriver = driver.copyWith(
///   status: DriverStatus.suspended,
///   suspensionReason: 'Multiple customer complaints',
///   suspensionExpiresAt: DateTime.now().add(Duration(days: 7)),
///   statusUpdatedAt: DateTime.now(),
/// );
/// ```
///
/// **Architecture Context:**
/// ```
/// Domain Layer (Driver Entity) ← YOU ARE HERE
///       ↓
/// Data Layer (DriverModel - serialization)
///       ↓
/// Infrastructure (Remote API + Local DB)
/// ```
///
/// **IMPROVEMENT:**
/// - [High Priority] Add email verification status field
/// - [High Priority] Add phone verification status field
/// - [Medium Priority] Add driver documents (license photo, insurance, vehicle registration)
/// - [Medium Priority] Add driver performance metrics (completed deliveries, cancellation rate)
/// - [Medium Priority] Add preferred delivery zones/areas
/// - [Low Priority] Add driver profile photo URL
/// - [Low Priority] Add driver preferences (max distance, preferred delivery types)
/// - [Low Priority] Add multilingual support for rejection/suspension reasons
class Driver extends Equatable {
  /// Unique identifier for the driver (UUID format)
  ///
  /// **Why separate from userId:**
  /// - Driver ID is driver-specific (driver profile)
  /// - User ID is user-specific (authentication account)
  /// - One user can potentially have both driver and customer profiles
  final String id;

  /// Reference to the authenticated user account
  ///
  /// **Usage:**
  /// - Links driver profile to user authentication
  /// - Enables cross-feature queries (user -> driver lookup)
  /// - Required for authorization checks
  final String userId;

  /// Driver's first name (validated: non-empty, trimmed)
  final String firstName;

  /// Driver's last name (validated: non-empty, trimmed)
  final String lastName;

  /// Driver's email address (validated: non-empty, valid email format)
  final String email;

  /// Driver's phone number (validated: non-empty, trimmed)
  ///
  /// **Format:** Supports international format (e.g., +2348012345678)
  final String phone;

  /// Driver's license number (validated: non-empty, trimmed)
  ///
  /// **Examples:**
  /// - Nigerian license: LAG-12345-AB
  /// - Required for driver verification
  final String licenseNumber;

  /// Driver's vehicle information (validated value object)
  ///
  /// **Contains:**
  /// - Vehicle plate number
  /// - Vehicle type (motorcycle, car, van, bicycle)
  /// - Make, model, year, color
  /// - See [VehicleInfo] for details
  final VehicleInfo vehicleInfo;

  /// Driver verification status
  ///
  /// **States:**
  /// - pending: Application under review
  /// - approved: Driver verified and can accept orders
  /// - rejected: Application denied
  /// - suspended: Account temporarily disabled
  ///
  /// **See:** [DriverStatus] enum for all states
  final DriverStatus status;

  /// Driver's current availability for order assignment
  ///
  /// **States:**
  /// - offline: Not working
  /// - available: Online and can accept orders
  /// - busy: Currently handling an order
  ///
  /// **See:** [AvailabilityStatus] enum for all states
  final AvailabilityStatus availability;

  /// Driver's current GPS location (null if offline or location not shared)
  ///
  /// **Usage:**
  /// - Real-time driver tracking
  /// - Nearest driver calculation
  /// - Delivery route optimization
  /// - Updated periodically when driver is online
  final Coordinate? currentLocation;

  /// Timestamp when location was last updated
  ///
  /// **Why important:**
  /// - Detect stale location data
  /// - Calculate time since last update
  /// - Filter out drivers with outdated locations
  final DateTime? lastLocationUpdate;

  /// Driver's average rating (0.0 - 5.0)
  ///
  /// **Validation:** Must be between 0 and 5 (inclusive)
  /// **Calculation:** Sum of all ratings / totalRatings
  final double rating;

  /// Total number of ratings received
  ///
  /// **Usage:**
  /// - Calculate average rating
  /// - Display rating confidence (e.g., "4.5 (100 ratings)")
  /// - Filter experienced drivers (e.g., min 10 ratings)
  final int totalRatings;

  /// Reason why driver application was rejected (null if not rejected)
  ///
  /// **Examples:**
  /// - "Invalid license number"
  /// - "Vehicle does not meet requirements"
  /// - "Background check failed"
  ///
  /// **Privacy:** Should only be visible to the driver and admin
  final String? rejectionReason;

  /// Reason why driver account was suspended (null if not suspended)
  ///
  /// **Examples:**
  /// - "Multiple customer complaints"
  /// - "Safety violation"
  /// - "Fraudulent activity detected"
  ///
  /// **Privacy:** Should only be visible to the driver and admin
  final String? suspensionReason;

  /// Date when suspension expires (null if not suspended or permanent)
  ///
  /// **Usage:**
  /// - Temporary suspensions (e.g., 7 days)
  /// - Auto-reactivation when suspension expires
  /// - Display "Suspended until {date}" in UI
  /// - null = permanent suspension or not suspended
  final DateTime? suspensionExpiresAt;

  /// Timestamp when driver status was last updated
  ///
  /// **Why important:**
  /// - Audit trail for status changes
  /// - Track verification processing time
  /// - Filter recently updated drivers
  final DateTime? statusUpdatedAt;

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
    this.rejectionReason,
    this.suspensionReason,
    this.suspensionExpiresAt,
    this.statusUpdatedAt,
  });

  /// Creates a Driver entity with comprehensive validation
  ///
  /// **What it does:**
  /// - Validates all required fields against business rules
  /// - Trims whitespace from string fields
  /// - Validates email format using regex
  /// - Validates rating range (0-5)
  /// - Returns validated Driver instance
  ///
  /// **Validation performed:**
  /// 1. First name: non-empty, trimmed
  /// 2. Last name: non-empty, trimmed
  /// 3. Email: non-empty, valid format (regex: ^[^@]+@[^@]+\.[^@]+$)
  /// 4. Phone: non-empty, trimmed
  /// 5. License number: non-empty, trimmed
  /// 6. Rating: 0-5 range (inclusive)
  /// 7. Vehicle info: validated via VehicleInfo value object
  ///
  /// **Throws:**
  /// - [ValidationException]: If any field validation fails
  ///
  /// **Parameters:**
  /// - [id]: Unique driver identifier (required)
  /// - [userId]: User account ID (required)
  /// - [firstName]: Driver's first name (required, validated)
  /// - [lastName]: Driver's last name (required, validated)
  /// - [email]: Driver's email (required, validated)
  /// - [phone]: Driver's phone (required, validated)
  /// - [licenseNumber]: Driver's license number (required, validated)
  /// - [vehicleInfo]: Vehicle details (required, validated)
  /// - [status]: Verification status (required)
  /// - [availability]: Current availability (required)
  /// - [currentLocation]: GPS coordinates (optional)
  /// - [lastLocationUpdate]: Location update timestamp (optional)
  /// - [rating]: Average rating 0-5 (required, validated)
  /// - [totalRatings]: Total rating count (required)
  /// - [rejectionReason]: Rejection explanation (optional)
  /// - [suspensionReason]: Suspension explanation (optional)
  /// - [suspensionExpiresAt]: Suspension expiry date (optional)
  /// - [statusUpdatedAt]: Status change timestamp (optional)
  ///
  /// **Example:**
  /// ```dart
  /// // Valid driver - succeeds
  /// final driver = Driver(
  ///   id: 'drv_123',
  ///   userId: 'usr_456',
  ///   firstName: 'Adebayo',
  ///   lastName: 'Johnson',
  ///   email: 'adebayo@example.com',
  ///   phone: '+2348012345678',
  ///   licenseNumber: 'LAG-12345-AB',
  ///   vehicleInfo: vehicleInfo,
  ///   status: DriverStatus.pending,
  ///   availability: AvailabilityStatus.offline,
  ///   rating: 0.0,
  ///   totalRatings: 0,
  /// );
  ///
  /// // Invalid email - throws ValidationException
  /// Driver(
  ///   ...
  ///   email: 'invalid-email',
  ///   ...
  /// ); // throws ValidationException
  ///
  /// // Invalid rating - throws ValidationException
  /// Driver(
  ///   ...
  ///   rating: 6.0, // > 5.0
  ///   ...
  /// ); // throws ValidationException
  /// ```
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
    String? rejectionReason,
    String? suspensionReason,
    DateTime? suspensionExpiresAt,
    DateTime? statusUpdatedAt,
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
      rejectionReason: rejectionReason?.trim(),
      suspensionReason: suspensionReason?.trim(),
      suspensionExpiresAt: suspensionExpiresAt,
      statusUpdatedAt: statusUpdatedAt,
    );
  }

  /// Returns driver's full name (first name + space + last name)
  ///
  /// **Example:** "Chidi Okonkwo"
  ///
  /// **Usage:**
  /// - Display driver name in UI
  /// - Driver profile header
  /// - Order assignment notifications
  String get fullName => '$firstName $lastName';

  /// Returns true if driver application is pending verification
  ///
  /// **Use cases:**
  /// - Show "Pending Approval" status in driver app
  /// - Filter drivers needing admin review
  /// - Display verification instructions
  bool get isPending => status == DriverStatus.pending;

  /// Returns true if driver is approved and verified
  ///
  /// **Use cases:**
  /// - Enable order acceptance functionality
  /// - Filter verified drivers for assignment
  /// - Show "Approved" badge in UI
  bool get isApproved => status == DriverStatus.approved;

  /// Returns true if driver application was rejected
  ///
  /// **Use cases:**
  /// - Show rejection message with reason
  /// - Prevent login to driver app
  /// - Display reapplication instructions
  bool get isRejected => status == DriverStatus.rejected;

  /// Returns true if driver account is suspended
  ///
  /// **Use cases:**
  /// - Block order acceptance
  /// - Show suspension message with reason and expiry
  /// - Prevent driver from going online
  bool get isSuspended => status == DriverStatus.suspended;

  /// Returns true if driver is online (available or busy)
  ///
  /// **What it checks:**
  /// - Availability is either available or busy
  /// - Does NOT check if status is approved
  ///
  /// **Use cases:**
  /// - Show "Online" indicator in admin dashboard
  /// - Filter active drivers
  /// - Track online driver count
  ///
  /// **Returns:** false if availability is offline
  bool get isOnline => availability.isOnline;

  /// Returns true if driver can accept new orders
  ///
  /// **Business logic:**
  /// - Driver must be approved (verified)
  /// - Driver must be available (not busy or offline)
  ///
  /// **Use cases:**
  /// - Filter drivers for automatic order assignment
  /// - Show "Accept Order" button in driver app
  /// - Calculate available driver count for dashboard
  ///
  /// **Returns:** false if not approved or not available
  bool get canAcceptOrders =>
      status == DriverStatus.approved && availability.canAcceptOrders;

  /// Returns true if driver has current location set
  ///
  /// **Use cases:**
  /// - Check if driver location is available for tracking
  /// - Filter drivers with known locations
  /// - Validate before showing driver on map
  ///
  /// **Returns:** false if currentLocation is null
  bool get hasLocation => currentLocation != null;

  /// Creates a copy of this driver with specified fields replaced
  ///
  /// **What it does:**
  /// - Creates new Driver instance with updated fields
  /// - Preserves unchanged fields from original
  /// - Re-runs validation on new field values
  /// - Enables immutable update pattern
  ///
  /// **Why immutable pattern:**
  /// - Prevents accidental mutations
  /// - Enables state comparison in BLoC/Redux
  /// - Thread-safe
  /// - Aligns with Clean Architecture principles
  ///
  /// **Parameters:** All optional, uses current value if not provided
  ///
  /// **Returns:** New Driver instance with updates
  ///
  /// **Example:**
  /// ```dart
  /// // Approve pending driver
  /// final approvedDriver = pendingDriver.copyWith(
  ///   status: DriverStatus.approved,
  ///   statusUpdatedAt: DateTime.now(),
  /// );
  ///
  /// // Update driver availability (go online)
  /// final onlineDriver = driver.copyWith(
  ///   availability: AvailabilityStatus.available,
  ///   currentLocation: Coordinate(latitude: 6.5244, longitude: 3.3792),
  ///   lastLocationUpdate: DateTime.now(),
  /// );
  ///
  /// // Suspend driver with reason
  /// final suspendedDriver = driver.copyWith(
  ///   status: DriverStatus.suspended,
  ///   suspensionReason: 'Multiple violations',
  ///   suspensionExpiresAt: DateTime.now().add(Duration(days: 7)),
  ///   statusUpdatedAt: DateTime.now(),
  /// );
  ///
  /// // Update rating after delivery
  /// final ratedDriver = driver.copyWith(
  ///   rating: 4.5,
  ///   totalRatings: driver.totalRatings + 1,
  /// );
  /// ```
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
    String? rejectionReason,
    String? suspensionReason,
    DateTime? suspensionExpiresAt,
    DateTime? statusUpdatedAt,
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
        rejectionReason: rejectionReason ?? this.rejectionReason,
        suspensionReason: suspensionReason ?? this.suspensionReason,
        suspensionExpiresAt: suspensionExpiresAt ?? this.suspensionExpiresAt,
        statusUpdatedAt: statusUpdatedAt ?? this.statusUpdatedAt,
      );

  /// Equatable props for value comparison
  ///
  /// **Why all fields:**
  /// - Two drivers are equal if ALL fields match
  /// - Enables deep equality checks
  /// - Used by Equatable for == operator and hashCode
  /// - Important for state management (detect driver changes)
  ///
  /// **Note:** Unlike User entity (which uses ID-only equality),
  /// Driver uses all-fields equality to detect any profile changes
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
        rejectionReason,
        suspensionReason,
        suspensionExpiresAt,
        statusUpdatedAt,
      ];

  /// String representation for debugging
  ///
  /// **Format:** Driver(id: ..., name: ..., status: ..., availability: ...)
  ///
  /// **Example output:**
  /// "Driver(id: drv_123, name: Chidi Okonkwo, status: Approved, availability: Available)"
  ///
  /// **Usage:**
  /// - Logging and debugging
  /// - Error messages
  /// - Development console output
  @override
  String toString() => 'Driver(id: $id, name: $fullName, '
      'status: ${status.displayName}, availability: ${availability.displayName})';
}
