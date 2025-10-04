import 'package:equatable/equatable.dart';
import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:delivery_app/shared/domain/value_objects/entity_id.dart';
import 'package:delivery_app/shared/domain/value_objects/email.dart';
import 'package:delivery_app/shared/domain/value_objects/phone_number.dart';
import 'package:delivery_app/features/auth/domain/entities/user_status.dart';
import 'package:delivery_app/features/auth/domain/entities/user_role.dart';

/// [User] - Core domain entity representing an authenticated user in the delivery app
///
/// **What it does:**
/// - Represents authenticated user with complete profile information
/// - Enforces business rules via validation (name length, role-specific data)
/// - Provides role-based queries (isDriver, isCustomer)
/// - Supports dual role system (driver vs customer)
/// - Validates role-specific data requirements
/// - Uses value objects for type safety (EntityID, Email, PhoneNumber)
/// - Immutable entity with copyWith pattern
///
/// **Why it exists:**
/// - Central identity representation across the app
/// - Enforces data integrity through validation
/// - Separates domain logic from presentation/infrastructure
/// - Enables role-based access control (RBAC)
/// - Type-safe user data (no invalid emails, phones, etc.)
/// - Clean Architecture domain layer entity
///
/// **Entity Validation Rules:**
/// - **First Name**: 2-50 characters, trimmed
/// - **Last Name**: 2-50 characters, trimmed
/// - **Email**: Valid email format (enforced by Email value object)
/// - **Phone**: Valid phone format (enforced by PhoneNumber value object)
/// - **Driver Role**: Must have driverData (throws if null)
/// - **Customer Role**: Must have customerData (throws if null)
///
/// **Usage Example:**
/// ```dart
/// // Create driver user
/// final driver = User(
///   id: EntityID('user_123'),
///   firstName: 'John',
///   lastName: 'Doe',
///   email: Email('john@example.com'),
///   phone: PhoneNumber('+1234567890'),
///   status: UserStatus.active,
///   role: UserRole.driver(),
///   driverData: DriverData(...), // Required for drivers
///   createdAt: DateTime.now(),
///   updatedAt: DateTime.now(),
/// );
///
/// // Check permissions
/// if (driver.isDriver && driver.isActive) {
///   print('Active driver: ${driver.fullName}');
/// }
///
/// // Update user
/// final updatedDriver = driver.copyWith(
///   status: UserStatus.inactive,
/// );
/// ```
///
/// **IMPROVEMENT:**
/// - [Medium Priority] Add email verification status field
/// - [Medium Priority] Add phone verification status field
/// - [Medium Priority] Add last login timestamp
/// - [Low Priority] Add profile picture URL
/// - [Low Priority] Add user preferences/settings
class User extends Equatable {
  /// Unique identifier for the user (UUID format)
  ///
  /// **Why EntityID value object:**
  /// - Type safety (can't pass wrong ID type)
  /// - Validation (ensures proper UUID format)
  /// - Domain-driven design pattern
  final EntityID id;

  /// User's first name (validated: 2-50 chars, trimmed)
  final String firstName;

  /// User's last name (validated: 2-50 chars, trimmed)
  final String lastName;

  /// User's email address (validated by Email value object)
  final Email email;

  /// User's phone number (validated by PhoneNumber value object)
  final PhoneNumber phone;

  /// Current account status (active, inactive, suspended, deleted)
  final UserStatus status;

  /// User's role with permissions (driver or customer)
  final UserRole role;

  /// Driver-specific data (required if role is driver, null otherwise)
  ///
  /// **Contains:**
  /// - Vehicle information
  /// - License details
  /// - Availability status
  /// - Driver-specific settings
  final DriverData? driverData;

  /// Customer-specific data (required if role is customer, null otherwise)
  ///
  /// **Contains:**
  /// - Delivery addresses
  /// - Payment methods
  /// - Order history
  /// - Customer preferences
  final CustomerData? customerData;

  /// Timestamp when user account was created
  final DateTime createdAt;

  /// Timestamp when user data was last updated
  final DateTime updatedAt;

  /// Creates a User entity with validation
  ///
  /// **Validation performed:**
  /// 1. First name: trimmed, 2-50 characters
  /// 2. Last name: trimmed, 2-50 characters
  /// 3. Email: valid format (via Email value object)
  /// 4. Phone: valid format (via PhoneNumber value object)
  /// 5. Role-specific data: drivers must have driverData, customers must have customerData
  ///
  /// **Throws:**
  /// - ArgumentError: If first/last name invalid
  /// - ArgumentError: If role-specific data missing
  ///
  /// **Parameters:**
  /// - [id]: Unique user identifier (required)
  /// - [firstName]: User's first name (required, validated)
  /// - [lastName]: User's last name (required, validated)
  /// - [email]: User's email (required, validated)
  /// - [phone]: User's phone (required, validated)
  /// - [status]: Account status (required)
  /// - [role]: User role with permissions (required)
  /// - [driverData]: Driver-specific data (required for drivers)
  /// - [customerData]: Customer-specific data (required for customers)
  /// - [createdAt]: Creation timestamp (required)
  /// - [updatedAt]: Last update timestamp (required)
  User({
    required this.id,
    required String firstName,
    required String lastName,
    required this.email,
    required this.phone,
    required this.status,
    required this.role,
    this.driverData,
    this.customerData,
    required this.createdAt,
    required this.updatedAt,
  })  : firstName = _validateFirstName(firstName),
        lastName = _validateLastName(lastName) {
    // Validate role-specific data
    if (role.type == UserRoleType.driver && driverData == null) {
      throw ArgumentError(AppStrings.errorDriverDataRequired);
    }
    if (role.type == UserRoleType.customer && customerData == null) {
      throw ArgumentError(AppStrings.errorCustomerDataRequired);
    }
  }

  /// Validates first name according to business rules
  ///
  /// **Validation rules:**
  /// - Not empty
  /// - Trimmed (leading/trailing whitespace removed)
  /// - Minimum 2 characters
  /// - Maximum 50 characters
  ///
  /// **Why these rules:**
  /// - Prevents single-character names (likely errors)
  /// - Prevents excessively long names (database limits)
  /// - Ensures consistent formatting (no extra spaces)
  ///
  /// **Throws:** ArgumentError if validation fails
  static String _validateFirstName(String firstName) {
    if (firstName.isEmpty) {
      throw ArgumentError(AppStrings.errorFirstNameEmpty);
    }

    final trimmed = firstName.trim();
    if (trimmed.length < 2) {
      throw ArgumentError(AppStrings.errorFirstNameTooShort);
    }

    if (trimmed.length > 50) {
      throw ArgumentError(AppStrings.errorFirstNameTooLong);
    }

    return trimmed;
  }

  /// Validates last name according to business rules
  ///
  /// **Validation rules:**
  /// - Not empty
  /// - Trimmed (leading/trailing whitespace removed)
  /// - Minimum 2 characters
  /// - Maximum 50 characters
  ///
  /// **Throws:** ArgumentError if validation fails
  static String _validateLastName(String lastName) {
    if (lastName.isEmpty) {
      throw ArgumentError(AppStrings.errorLastNameEmpty);
    }

    final trimmed = lastName.trim();
    if (trimmed.length < 2) {
      throw ArgumentError(AppStrings.errorLastNameTooShort);
    }

    if (trimmed.length > 50) {
      throw ArgumentError(AppStrings.errorLastNameTooLong);
    }

    return trimmed;
  }

  /// Returns user's full name (first name + space + last name)
  ///
  /// **Example:** "John Doe"
  String get fullName => '$firstName $lastName';

  /// Returns true if user account is active
  ///
  /// **Use cases:**
  /// - Prevent login for inactive users
  /// - Show account status in UI
  /// - Enable/disable features based on status
  bool get isActive => status == UserStatus.active;

  /// Returns true if user has driver role
  ///
  /// **Use cases:**
  /// - Show driver-specific UI (delivery map, order list)
  /// - Enable driver features
  /// - Route to driver dashboard
  bool get isDriver => role.type == UserRoleType.driver;

  /// Returns true if user has customer role
  ///
  /// **Use cases:**
  /// - Show customer-specific UI (order tracking, restaurants)
  /// - Enable customer features
  /// - Route to customer dashboard
  bool get isCustomer => role.type == UserRoleType.customer;

  /// Returns true if driver is currently available for deliveries
  ///
  /// **What it checks:**
  /// - User must be a driver (isDriver)
  /// - Driver data must exist
  /// - Driver's isAvailable flag must be true
  ///
  /// **Use cases:**
  /// - Show availability toggle in driver UI
  /// - Filter available drivers for order assignment
  /// - Display "Available" / "Unavailable" status
  ///
  /// **Returns:** false for customers or unavailable drivers
  bool get isAvailable => isDriver && driverData?.isAvailable == true;

  /// Checks if user has a specific permission
  ///
  /// **What it does:**
  /// - Delegates to UserRole.hasPermission()
  /// - Checks against role's permission list
  ///
  /// **Parameters:**
  /// - [permission]: Permission string to check (e.g., "orders.view", "deliveries.accept")
  ///
  /// **Returns:** true if user's role includes the permission
  ///
  /// **Example:**
  /// ```dart
  /// if (user.hasPermission('orders.cancel')) {
  ///   showCancelButton();
  /// }
  /// ```
  bool hasPermission(String permission) => role.hasPermission(permission);

  /// Creates a copy of this user with specified fields replaced
  ///
  /// **What it does:**
  /// - Creates new User instance with updated fields
  /// - Preserves unchanged fields from original
  /// - Always updates updatedAt timestamp
  /// - Re-runs validation on new field values
  ///
  /// **Why immutable pattern:**
  /// - Prevents accidental mutations
  /// - Enables state comparison
  /// - Thread-safe
  /// - Aligns with Clean Architecture principles
  ///
  /// **Parameters:** All optional, uses current value if not provided
  ///
  /// **Returns:** New User instance with updates
  ///
  /// **Example:**
  /// ```dart
  /// // Update user status
  /// final inactiveUser = user.copyWith(status: UserStatus.inactive);
  ///
  /// // Update driver availability
  /// final unavailableDriver = user.copyWith(
  ///   driverData: user.driverData?.copyWith(isAvailable: false),
  /// );
  /// ```
  ///
  /// **IMPROVEMENT:**
  /// - [Low Priority] Add validation to prevent invalid state transitions
  User copyWith({
    EntityID? id,
    String? firstName,
    String? lastName,
    Email? email,
    PhoneNumber? phone,
    UserStatus? status,
    UserRole? role,
    DriverData? driverData,
    CustomerData? customerData,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      User(
        id: id ?? this.id,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        status: status ?? this.status,
        role: role ?? this.role,
        driverData: driverData ?? this.driverData,
        customerData: customerData ?? this.customerData,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? DateTime.now(), // Always update the timestamp
      );

  /// Equatable props - equality based on ID only
  ///
  /// **Why ID-only equality:**
  /// - Two users with same ID are the same user (even if data differs)
  /// - Aligns with database identity semantics
  /// - Simplifies comparison logic
  @override
  List<Object> get props => [id]; // Equality based on ID only

  /// String representation for debugging
  ///
  /// **Format:** User(id: ..., name: ..., email: ..., role: ..., status: ...)
  @override
  String toString() =>
      'User(id: $id, name: $fullName, email: $email, role: ${role.type}, status: $status)';
}
