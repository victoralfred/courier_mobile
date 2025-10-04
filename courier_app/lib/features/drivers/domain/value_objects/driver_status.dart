/// [DriverStatus] - Enum value object representing driver verification status
///
/// **What it does:**
/// - Defines driver account approval states
/// - Tracks driver verification workflow progress
/// - Controls driver access to order acceptance
/// - Enables admin moderation of driver applications
/// - Type-safe status representation (no string errors)
///
/// **Why it exists:**
/// - Enforces driver verification workflow
/// - Prevents unverified drivers from accepting orders
/// - Tracks rejection and suspension reasons
/// - Enables admin dashboard filtering
/// - Type-safe status transitions
///
/// **Status Workflow:**
/// ```
/// pending → approved (driver verified by admin)
/// pending → rejected (driver application denied)
/// approved → suspended (violation detected)
/// suspended → approved (suspension lifted)
/// ```
///
/// **Business Logic:**
/// - Only approved drivers can accept orders
/// - Pending drivers await admin review
/// - Rejected drivers cannot reapply (without admin action)
/// - Suspended drivers are temporarily blocked
///
/// **Usage Example:**
/// ```dart
/// // Create pending driver
/// final driver = Driver(
///   ...
///   status: DriverStatus.pending,
/// );
///
/// // Admin approves driver
/// final approvedDriver = driver.copyWith(
///   status: DriverStatus.approved,
///   statusUpdatedAt: DateTime.now(),
/// );
///
/// // Check if can accept orders
/// if (driver.status == DriverStatus.approved) {
///   enableOrderAcceptance();
/// }
///
/// // Suspend driver
/// final suspendedDriver = driver.copyWith(
///   status: DriverStatus.suspended,
///   suspensionReason: 'Multiple violations',
///   suspensionExpiresAt: DateTime.now().add(Duration(days: 7)),
/// );
/// ```
///
/// **IMPROVEMENT:**
/// - [Medium Priority] Add inactive status (long-term dormant drivers)
/// - [Low Priority] Add deactivated status (driver voluntarily disabled account)
enum DriverStatus {
  /// Driver application pending review
  pending,

  /// Driver approved and can accept orders
  approved,

  /// Driver application rejected
  rejected,

  /// Driver account suspended (violation or safety concerns)
  suspended,
}

/// [DriverStatusExtension] - Extension methods for DriverStatus enum
///
/// **What it provides:**
/// - JSON serialization (toJson)
/// - User-friendly display names (displayName)
///
/// **Usage Example:**
/// ```dart
/// final status = DriverStatus.approved;
/// print(status.toJson()); // 'approved'
/// print(status.displayName); // 'Approved'
/// ```
extension DriverStatusExtension on DriverStatus {
  /// Converts enum to JSON string for API communication
  ///
  /// **Returns:** Lowercase string representation
  /// **Usage:** Serialization to backend API, local database
  ///
  /// **Examples:**
  /// - DriverStatus.pending → 'pending'
  /// - DriverStatus.approved → 'approved'
  /// - DriverStatus.rejected → 'rejected'
  /// - DriverStatus.suspended → 'suspended'
  String toJson() {
    switch (this) {
      case DriverStatus.pending:
        return 'pending';
      case DriverStatus.approved:
        return 'approved';
      case DriverStatus.rejected:
        return 'rejected';
      case DriverStatus.suspended:
        return 'suspended';
    }
  }

  /// Returns user-friendly display name for UI presentation
  ///
  /// **Returns:** Capitalized, human-readable status name
  /// **Usage:** Status badges, driver profile UI, admin dashboard
  ///
  /// **Examples:**
  /// - DriverStatus.pending → 'Pending Verification'
  /// - DriverStatus.approved → 'Approved'
  /// - DriverStatus.rejected → 'Rejected'
  /// - DriverStatus.suspended → 'Suspended'
  String get displayName {
    switch (this) {
      case DriverStatus.pending:
        return 'Pending Verification';
      case DriverStatus.approved:
        return 'Approved';
      case DriverStatus.rejected:
        return 'Rejected';
      case DriverStatus.suspended:
        return 'Suspended';
    }
  }
}

/// [DriverStatusHelper] - Helper class for DriverStatus deserialization
///
/// **What it does:**
/// - Parses string values to DriverStatus enum
/// - Handles case-insensitive parsing
/// - Validates status values
///
/// **Usage Example:**
/// ```dart
/// // Parse from API response
/// final status = DriverStatusHelper.fromString('approved');
///
/// // Case-insensitive
/// final status2 = DriverStatusHelper.fromString('PENDING');
///
/// // Invalid status throws error
/// try {
///   final invalid = DriverStatusHelper.fromString('unknown');
/// } catch (e) {
///   print('Invalid status: $e'); // ArgumentError
/// }
/// ```
class DriverStatusHelper {
  /// Parses driver status from string (case-insensitive)
  ///
  /// **Parameters:**
  /// - [value]: Status string (e.g., 'pending', 'approved', 'REJECTED')
  ///
  /// **Returns:** Corresponding DriverStatus enum value
  ///
  /// **Throws:**
  /// - ArgumentError: If value is not a valid status
  ///
  /// **Supported values:**
  /// - 'pending' → DriverStatus.pending
  /// - 'approved' → DriverStatus.approved
  /// - 'rejected' → DriverStatus.rejected
  /// - 'suspended' → DriverStatus.suspended
  static DriverStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
        return DriverStatus.pending;
      case 'approved':
        return DriverStatus.approved;
      case 'rejected':
        return DriverStatus.rejected;
      case 'suspended':
        return DriverStatus.suspended;
      default:
        throw ArgumentError('Invalid driver status: $value');
    }
  }
}
