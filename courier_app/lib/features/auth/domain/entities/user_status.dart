/// [UserStatus] - Enum representing user account status states
///
/// **What it does:**
/// - Defines possible account states (active, inactive)
/// - Provides status validation for user entities
/// - Enables status-based access control
/// - Supports API serialization/deserialization
/// - Type-safe status representation
///
/// **Why it exists:**
/// - Enforce valid status values (prevents invalid states)
/// - Enable account lifecycle management
/// - Support user suspension/deactivation flows
/// - Consistent status representation across app
/// - Type safety (prevents string typos)
/// - Clean Architecture domain layer value
///
/// **Status Rules:**
/// - **Active**: User can perform all authorized actions
/// - **Inactive**: User account restricted, cannot login or perform actions
///
/// **Usage Example:**
/// ```dart
/// // Check user status
/// if (user.status == UserStatus.active) {
///   await loginUser(user);
/// }
///
/// // Deactivate user
/// final inactiveUser = user.copyWith(
///   status: UserStatus.inactive,
/// );
///
/// // Parse from API
/// final status = UserStatusExtension.fromString('active');
///
/// // Convert to API format
/// final apiValue = UserStatus.active.value; // 'active'
/// ```
///
/// **IMPROVEMENT:**
/// - [High Priority] Add 'suspended' status for temporary account suspension
/// - [High Priority] Add 'deleted' status for soft-deleted accounts
/// - [Medium Priority] Add 'pending_verification' for unverified accounts
/// - [Medium Priority] Add status transition validation (prevent invalid transitions)
/// - [Low Priority] Add status change reason/metadata tracking
enum UserStatus {
  /// User account is active and can perform all actions
  ///
  /// **Allows:**
  /// - Login and authentication
  /// - All role-based permissions
  /// - Profile updates
  /// - Feature access
  active,

  /// User account is inactive and restricted from certain actions
  ///
  /// **Prevents:**
  /// - Login attempts
  /// - API access
  /// - Feature usage
  ///
  /// **Use cases:**
  /// - User requested account deactivation
  /// - Administrative restriction
  /// - Account under review
  inactive,
}

/// Extension methods for UserStatus enum
///
/// **What it provides:**
/// - String conversion for API communication
/// - Parsing from API string responses
/// - Type-safe status handling
///
/// **Why extension pattern:**
/// - Keeps enum clean and simple
/// - Separates serialization logic
/// - Maintains enum immutability
/// - Follows Dart best practices
extension UserStatusExtension on UserStatus {
  /// Get string representation for API communication
  ///
  /// **What it does:**
  /// - Converts enum to lowercase string
  /// - Matches backend API format
  ///
  /// **Returns:**
  /// - 'active' for UserStatus.active
  /// - 'inactive' for UserStatus.inactive
  ///
  /// **Example:**
  /// ```dart
  /// final status = UserStatus.active;
  /// final apiValue = status.value; // 'active'
  /// await api.updateStatus(userId, apiValue);
  /// ```
  String get value {
    switch (this) {
      case UserStatus.active:
        return 'active';
      case UserStatus.inactive:
        return 'inactive';
    }
  }

  /// Create UserStatus from string value
  ///
  /// **What it does:**
  /// - Parses API string response to enum
  /// - Case-insensitive parsing
  /// - Validates input format
  ///
  /// **Parameters:**
  /// - [value]: Status string from API (case-insensitive)
  ///
  /// **Returns:** Matching UserStatus enum value
  ///
  /// **Throws:** ArgumentError if value is invalid
  ///
  /// **Example:**
  /// ```dart
  /// // Parse API response
  /// final status = UserStatusExtension.fromString('active');
  /// final status2 = UserStatusExtension.fromString('INACTIVE'); // case-insensitive
  ///
  /// // Throws ArgumentError
  /// try {
  ///   UserStatusExtension.fromString('deleted');
  /// } catch (e) {
  ///   print(e); // Invalid user status: deleted
  /// }
  /// ```
  static UserStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'active':
        return UserStatus.active;
      case 'inactive':
        return UserStatus.inactive;
      default:
        throw ArgumentError('Invalid user status: $value');
    }
  }
}