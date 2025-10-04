import 'package:equatable/equatable.dart';
import 'package:delivery_app/core/constants/app_strings.dart';

/// [UserRoleType] - Enum representing user roles in the delivery system
///
/// **What it does:**
/// - Defines three distinct user roles (customer, driver, admin)
/// - Enables role-based access control (RBAC)
/// - Type-safe role representation
/// - Supports role-specific features and UI
///
/// **Why it exists:**
/// - Separate concerns between user types
/// - Control feature access by role
/// - Route users to appropriate dashboards
/// - Enforce role-specific business rules
/// - Type safety (prevents invalid role values)
///
/// **Role Hierarchy:**
/// - **Customer**: Orders and tracks deliveries
/// - **Driver**: Accepts and completes deliveries
/// - **Admin**: System administration (treated as customer in current implementation)
///
/// **Usage Example:**
/// ```dart
/// // Check role type
/// if (user.role.type == UserRoleType.driver) {
///   showDriverDashboard();
/// }
///
/// // Create role-specific entities
/// final role = UserRoleType.customer;
/// final permissions = role.displayName; // "Customer"
/// ```
///
/// **IMPROVEMENT:**
/// - [Medium Priority] Implement proper admin role handling (currently treated as customer)
/// - [Low Priority] Add role hierarchy (admin > driver > customer)
/// - [Low Priority] Add custom roles with configurable permissions
enum UserRoleType {
  /// Customer role - can order and track deliveries
  customer,

  /// Driver role - can accept and complete deliveries
  driver,

  /// Admin role - system administration (currently mapped to customer)
  admin,
}

/// Extension methods for UserRoleType enum
///
/// **What it provides:**
/// - Human-readable role names for UI
/// - API string serialization
/// - Role parsing from API responses
///
/// **Why extension pattern:**
/// - Keeps enum clean
/// - Separates presentation/serialization logic
/// - Maintains immutability
extension UserRoleTypeExtension on UserRoleType {
  /// Get the display name for the role
  ///
  /// **What it does:**
  /// - Returns localized/friendly role name
  /// - Used in UI elements (dropdowns, labels)
  ///
  /// **Returns:**
  /// - Localized string from AppStrings
  /// - "Customer", "Driver", or "Admin"
  ///
  /// **Example:**
  /// ```dart
  /// final roleName = UserRoleType.driver.displayName; // "Driver"
  /// Text('Role: $roleName'); // Display in UI
  /// ```
  String get displayName {
    switch (this) {
      case UserRoleType.customer:
        return AppStrings.roleCustomer;
      case UserRoleType.driver:
        return AppStrings.roleDriver;
      case UserRoleType.admin:
        return 'Admin';
    }
  }

  /// Get the role value for API communication
  ///
  /// **What it does:**
  /// - Converts enum to lowercase string
  /// - Matches backend API format
  ///
  /// **Returns:** 'customer', 'driver', or 'admin'
  ///
  /// **Example:**
  /// ```dart
  /// final apiRole = UserRoleType.driver.value; // 'driver'
  /// await api.assignRole(userId, apiRole);
  /// ```
  String get value {
    switch (this) {
      case UserRoleType.customer:
        return 'customer';
      case UserRoleType.driver:
        return 'driver';
      case UserRoleType.admin:
        return 'admin';
    }
  }

  /// Parse UserRoleType from string
  ///
  /// **What it does:**
  /// - Parses API string to enum
  /// - Case-insensitive parsing
  /// - Defaults to customer for unknown roles
  ///
  /// **Important:** Admin is currently treated as customer
  ///
  /// **Parameters:**
  /// - [value]: Role string from API (case-insensitive)
  ///
  /// **Returns:** UserRoleType (defaults to customer if invalid)
  ///
  /// **Example:**
  /// ```dart
  /// final role = UserRoleTypeExtension.fromString('driver');
  /// final role2 = UserRoleTypeExtension.fromString('CUSTOMER');
  /// final unknown = UserRoleTypeExtension.fromString('invalid'); // customer
  /// ```
  ///
  /// **IMPROVEMENT:**
  /// - [High Priority] Throw error for invalid roles instead of defaulting
  static UserRoleType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'customer':
        return UserRoleType.customer;
      case 'driver':
        return UserRoleType.driver;
      case 'admin':
        // Treat admin as customer for now (they can access customer features)
        return UserRoleType.customer;
      default:
        // Default to customer role for unknown roles
        return UserRoleType.customer;
    }
  }
}

/// [UserRole] - Domain entity representing user role with associated permissions
///
/// **What it does:**
/// - Associates role type with specific permissions
/// - Implements permission-based access control
/// - Tracks when role was assigned
/// - Provides factory methods for common roles
/// - Immutable entity following Clean Architecture
///
/// **Why it exists:**
/// - Centralized permission management
/// - Type-safe permission checking
/// - Prevents direct permission manipulation
/// - Supports role-based UI and feature gating
/// - Enables future role customization
/// - Clean separation of roles and permissions
///
/// **Permission Model:**
/// - Permissions are string-based identifiers
/// - Each role has predefined permission set
/// - Permissions checked via hasPermission() method
/// - Extensible for new permissions
///
/// **Usage Example:**
/// ```dart
/// // Create roles using factories
/// final customerRole = UserRole.customer();
/// final driverRole = UserRole.driver();
///
/// // Check permissions
/// if (user.role.hasPermission('orders.create')) {
///   showCreateOrderButton();
/// }
///
/// // Custom role
/// final customRole = UserRole(
///   type: UserRoleType.driver,
///   permissions: ['deliveries.view', 'deliveries.accept'],
///   assignedAt: DateTime.now(),
/// );
/// ```
///
/// **IMPROVEMENT:**
/// - [High Priority] Add role change audit trail
/// - [Medium Priority] Implement permission groups/categories
/// - [Medium Priority] Add role expiration/temporary roles
/// - [Low Priority] Support multiple roles per user
/// - [Low Priority] Add permission inheritance/hierarchies
class UserRole extends Equatable {
  /// The type of role (customer, driver, admin)
  final UserRoleType type;

  /// List of permission strings granted to this role
  ///
  /// **Format:** 'resource.action' (e.g., 'orders.create', 'profile.update')
  ///
  /// **Common permissions:**
  /// - Customer: create/view/cancel/track orders, rate driver
  /// - Driver: view/accept/reject orders, update location, view earnings
  final List<String> permissions;

  /// Timestamp when the role was assigned to the user
  ///
  /// **Use cases:**
  /// - Audit trail
  /// - Role duration tracking
  /// - Analytics on role changes
  final DateTime assignedAt;

  /// Creates a UserRole with specified type and permissions
  ///
  /// **Parameters:**
  /// - [type]: The role type (required)
  /// - [permissions]: List of permission strings (required)
  /// - [assignedAt]: Assignment timestamp (required)
  ///
  /// **Note:** Prefer using factory methods (customer(), driver()) for standard roles
  const UserRole({
    required this.type,
    required this.permissions,
    required this.assignedAt,
  });

  /// Check if the role has a specific permission
  ///
  /// **What it does:**
  /// - Searches permission list for exact match
  /// - Case-sensitive comparison
  ///
  /// **Parameters:**
  /// - [permission]: Permission string to check (e.g., 'orders.create')
  ///
  /// **Returns:** true if permission exists in role's permission list
  ///
  /// **Example:**
  /// ```dart
  /// if (role.hasPermission('deliveries.accept')) {
  ///   // User can accept deliveries
  /// }
  /// ```
  bool hasPermission(String permission) => permissions.contains(permission);

  /// Create a Customer role with default permissions
  ///
  /// **What it does:**
  /// - Creates role with customer permissions
  /// - Sets assignedAt to current time
  ///
  /// **Customer permissions:**
  /// - Create, view, cancel, track orders
  /// - Rate drivers
  /// - View and update profile
  ///
  /// **Returns:** UserRole configured for customer
  ///
  /// **Example:**
  /// ```dart
  /// final user = User(
  ///   role: UserRole.customer(),
  ///   // ... other fields
  /// );
  /// ```
  factory UserRole.customer() => UserRole(
        type: UserRoleType.customer,
        permissions: [
          AppStrings.permissionCreateOrder,
          AppStrings.permissionViewOrder,
          AppStrings.permissionCancelOrder,
          AppStrings.permissionTrackOrder,
          AppStrings.permissionRateDriver,
          AppStrings.permissionViewProfile,
          AppStrings.permissionUpdateProfile,
        ],
        assignedAt: DateTime.now(),
      );

  /// Create a Driver role with default permissions
  ///
  /// **What it does:**
  /// - Creates role with driver permissions
  /// - Sets assignedAt to current time
  ///
  /// **Driver permissions:**
  /// - View, accept, reject orders
  /// - Update order status and delivery location
  /// - Update availability status
  /// - View earnings
  /// - View and update profile
  ///
  /// **Returns:** UserRole configured for driver
  ///
  /// **Example:**
  /// ```dart
  /// final driver = User(
  ///   role: UserRole.driver(),
  ///   driverData: DriverData(...),
  ///   // ... other fields
  /// );
  /// ```
  factory UserRole.driver() => UserRole(
        type: UserRoleType.driver,
        permissions: [
          AppStrings.permissionViewOrder,
          AppStrings.permissionAcceptOrder,
          AppStrings.permissionRejectOrder,
          AppStrings.permissionUpdateOrderStatus,
          AppStrings.permissionUpdateLocation,
          AppStrings.permissionViewEarnings,
          AppStrings.permissionViewProfile,
          AppStrings.permissionUpdateProfile,
          AppStrings.permissionUpdateAvailability,
        ],
        assignedAt: DateTime.now(),
      );

  /// Equatable props - equality based on all fields
  @override
  List<Object> get props => [type, permissions, assignedAt];

  /// String representation for debugging
  ///
  /// **Format:** UserRole(type: ..., permissions: N)
  @override
  String toString() =>
      'UserRole(type: $type, permissions: ${permissions.length})';
}

/// [DriverData] - Value object containing driver-specific information
///
/// **What it does:**
/// - Stores vehicle and license information
/// - Tracks driver availability status
/// - Maintains performance metrics (rating, deliveries)
/// - Stores real-time location data
/// - Immutable with copyWith pattern
///
/// **Why it exists:**
/// - Separate driver-specific data from core User entity
/// - Enable driver features (order assignment, location tracking)
/// - Support driver performance tracking
/// - Required for users with driver role
/// - Clean separation of concerns
///
/// **Data Categories:**
/// - **Vehicle Info**: Type, number, license
/// - **Availability**: Online/offline status
/// - **Performance**: Rating, completed deliveries
/// - **Location**: GPS coordinates, last update time
///
/// **Usage Example:**
/// ```dart
/// // Create driver data
/// final driverData = DriverData(
///   vehicleType: 'Motorcycle',
///   vehicleNumber: 'ABC-123',
///   licenseNumber: 'DL12345',
///   isAvailable: true,
///   rating: 4.8,
///   completedDeliveries: 150,
/// );
///
/// // Update availability
/// final unavailable = driverData.copyWith(isAvailable: false);
///
/// // Update location
/// final withLocation = driverData.copyWith(
///   latitude: 37.7749,
///   longitude: -122.4194,
///   lastLocationUpdate: DateTime.now(),
/// );
/// ```
///
/// **IMPROVEMENT:**
/// - [High Priority] Add vehicle photo/document URLs
/// - [High Priority] Add license expiry date validation
/// - [Medium Priority] Add vehicle capacity/specifications
/// - [Medium Priority] Add driver certification status
/// - [Low Priority] Add preferred delivery zones
/// - [Low Priority] Add working hours/schedule
class DriverData extends Equatable {
  /// Type of vehicle used for deliveries (e.g., 'Motorcycle', 'Car', 'Bicycle')
  ///
  /// **Optional**: May be null during initial registration
  final String? vehicleType;

  /// Vehicle registration/license plate number
  ///
  /// **Optional**: May be null during initial registration
  final String? vehicleNumber;

  /// Driver's license number
  ///
  /// **Optional**: May be null during initial registration
  /// **Security**: Should be encrypted in storage
  final String? licenseNumber;

  /// Whether driver is currently available for deliveries
  ///
  /// **Default**: false (offline by default)
  ///
  /// **Use cases:**
  /// - Order assignment eligibility
  /// - Driver availability display
  /// - Automatic status changes (e.g., during active delivery)
  final bool isAvailable;

  /// Driver's average rating from customers (0.0 to 5.0)
  ///
  /// **Optional**: Null until first rating received
  /// **Range**: 0.0 - 5.0
  final double? rating;

  /// Total number of completed deliveries
  ///
  /// **Default**: 0
  ///
  /// **Use cases:**
  /// - Driver experience level
  /// - Performance analytics
  /// - Achievement/badge systems
  final int completedDeliveries;

  /// Timestamp of last location update
  ///
  /// **Optional**: Null if location never updated
  ///
  /// **Use cases:**
  /// - Detect stale location data
  /// - Track location update frequency
  /// - Driver activity monitoring
  final DateTime? lastLocationUpdate;

  /// Driver's current latitude coordinate
  ///
  /// **Optional**: Null if location not available
  /// **Range**: -90.0 to 90.0
  final double? latitude;

  /// Driver's current longitude coordinate
  ///
  /// **Optional**: Null if location not available
  /// **Range**: -180.0 to 180.0
  final double? longitude;

  /// Creates DriverData with specified values
  ///
  /// **Parameters:**
  /// - [vehicleType]: Vehicle type (optional)
  /// - [vehicleNumber]: Vehicle registration (optional)
  /// - [licenseNumber]: Driver's license (optional)
  /// - [isAvailable]: Availability status (default: false)
  /// - [rating]: Average rating (optional, 0.0-5.0)
  /// - [completedDeliveries]: Delivery count (default: 0)
  /// - [lastLocationUpdate]: Last GPS update time (optional)
  /// - [latitude]: Current latitude (optional)
  /// - [longitude]: Current longitude (optional)
  const DriverData({
    this.vehicleType,
    this.vehicleNumber,
    this.licenseNumber,
    this.isAvailable = false,
    this.rating,
    this.completedDeliveries = 0,
    this.lastLocationUpdate,
    this.latitude,
    this.longitude,
  });

  /// Create a copy with updated fields
  ///
  /// **What it does:**
  /// - Creates new DriverData with specified changes
  /// - Preserves unchanged fields
  /// - Maintains immutability
  ///
  /// **Parameters:** All optional, uses current value if not provided
  ///
  /// **Returns:** New DriverData instance with updates
  ///
  /// **Example:**
  /// ```dart
  /// // Update only availability
  /// final updated = driverData.copyWith(isAvailable: true);
  ///
  /// // Update location
  /// final withLocation = driverData.copyWith(
  ///   latitude: 37.7749,
  ///   longitude: -122.4194,
  ///   lastLocationUpdate: DateTime.now(),
  /// );
  /// ```
  DriverData copyWith({
    String? vehicleType,
    String? vehicleNumber,
    String? licenseNumber,
    bool? isAvailable,
    double? rating,
    int? completedDeliveries,
    DateTime? lastLocationUpdate,
    double? latitude,
    double? longitude,
  }) =>
      DriverData(
        vehicleType: vehicleType ?? this.vehicleType,
        vehicleNumber: vehicleNumber ?? this.vehicleNumber,
        licenseNumber: licenseNumber ?? this.licenseNumber,
        isAvailable: isAvailable ?? this.isAvailable,
        rating: rating ?? this.rating,
        completedDeliveries: completedDeliveries ?? this.completedDeliveries,
        lastLocationUpdate: lastLocationUpdate ?? this.lastLocationUpdate,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
      );

  /// Equatable props - equality based on all fields
  @override
  List<Object?> get props => [
        vehicleType,
        vehicleNumber,
        licenseNumber,
        isAvailable,
        rating,
        completedDeliveries,
        lastLocationUpdate,
        latitude,
        longitude,
      ];
}

/// [CustomerData] - Value object containing customer-specific information
///
/// **What it does:**
/// - Stores saved delivery addresses
/// - Tracks preferred payment method
/// - Maintains order history count
/// - Stores customer rating (from drivers)
/// - Immutable with copyWith pattern
///
/// **Why it exists:**
/// - Separate customer-specific data from core User entity
/// - Enable customer features (quick address selection, payment preferences)
/// - Support customer analytics and personalization
/// - Required for users with customer role
/// - Clean separation of concerns
///
/// **Data Categories:**
/// - **Addresses**: Saved delivery locations
/// - **Payment**: Preferred payment method
/// - **History**: Total orders placed
/// - **Reputation**: Customer rating
///
/// **Usage Example:**
/// ```dart
/// // Create customer data
/// final customerData = CustomerData(
///   savedAddresses: ['123 Main St', '456 Oak Ave'],
///   preferredPaymentMethod: 'credit_card',
///   totalOrders: 25,
///   rating: 4.9,
/// );
///
/// // Add new address
/// final updated = customerData.copyWith(
///   savedAddresses: [...customerData.savedAddresses, '789 Elm St'],
/// );
///
/// // Update payment preference
/// final withPayment = customerData.copyWith(
///   preferredPaymentMethod: 'paypal',
/// );
/// ```
///
/// **IMPROVEMENT:**
/// - [High Priority] Replace string addresses with Address value objects
/// - [High Priority] Add payment method details (last 4 digits, type)
/// - [Medium Priority] Add delivery preferences (instructions, contact preference)
/// - [Medium Priority] Add favorite restaurants/stores
/// - [Low Priority] Add loyalty points/rewards
/// - [Low Priority] Add dietary restrictions/preferences
class CustomerData extends Equatable {
  /// List of saved delivery addresses
  ///
  /// **Default**: Empty list
  ///
  /// **Use cases:**
  /// - Quick address selection during checkout
  /// - Address history
  /// - Default/primary address selection
  ///
  /// **IMPROVEMENT:** Should be Address value objects instead of strings
  final List<String> savedAddresses;

  /// Preferred payment method identifier
  ///
  /// **Optional**: Null if not set
  ///
  /// **Examples:**
  /// - 'credit_card'
  /// - 'paypal'
  /// - 'cash'
  /// - 'debit_card'
  ///
  /// **Use cases:**
  /// - Auto-select payment during checkout
  /// - Payment preference display
  final String? preferredPaymentMethod;

  /// Total number of orders placed by customer
  ///
  /// **Default**: 0
  ///
  /// **Use cases:**
  /// - Customer loyalty tier
  /// - Analytics and reporting
  /// - Promotional eligibility
  final int totalOrders;

  /// Customer's rating from drivers (0.0 to 5.0)
  ///
  /// **Optional**: Null until first rating received
  /// **Range**: 0.0 - 5.0
  ///
  /// **Use cases:**
  /// - Driver visibility into customer reliability
  /// - Account status monitoring
  final double? rating;

  /// Creates CustomerData with specified values
  ///
  /// **Parameters:**
  /// - [savedAddresses]: Saved delivery addresses (default: empty)
  /// - [preferredPaymentMethod]: Preferred payment (optional)
  /// - [totalOrders]: Order count (default: 0)
  /// - [rating]: Customer rating (optional, 0.0-5.0)
  const CustomerData({
    this.savedAddresses = const [],
    this.preferredPaymentMethod,
    this.totalOrders = 0,
    this.rating,
  });

  /// Create a copy with updated fields
  ///
  /// **What it does:**
  /// - Creates new CustomerData with specified changes
  /// - Preserves unchanged fields
  /// - Maintains immutability
  ///
  /// **Parameters:** All optional, uses current value if not provided
  ///
  /// **Returns:** New CustomerData instance with updates
  ///
  /// **Example:**
  /// ```dart
  /// // Add address
  /// final updated = customerData.copyWith(
  ///   savedAddresses: [...customerData.savedAddresses, 'New Address'],
  /// );
  ///
  /// // Increment order count
  /// final afterOrder = customerData.copyWith(
  ///   totalOrders: customerData.totalOrders + 1,
  /// );
  /// ```
  CustomerData copyWith({
    List<String>? savedAddresses,
    String? preferredPaymentMethod,
    int? totalOrders,
    double? rating,
  }) =>
      CustomerData(
        savedAddresses: savedAddresses ?? this.savedAddresses,
        preferredPaymentMethod:
            preferredPaymentMethod ?? this.preferredPaymentMethod,
        totalOrders: totalOrders ?? this.totalOrders,
        rating: rating ?? this.rating,
      );

  /// Equatable props - equality based on all fields
  @override
  List<Object?> get props => [
        savedAddresses,
        preferredPaymentMethod,
        totalOrders,
        rating,
      ];
}
