/// [AvailabilityStatus] - Enum value object representing driver availability state
///
/// **What it does:**
/// - Defines driver online/offline status
/// - Controls driver visibility for order assignment
/// - Tracks driver work state (available vs busy)
/// - Enables real-time driver availability tracking
/// - Type-safe availability representation
///
/// **Why it exists:**
/// - Prevents order assignment to offline drivers
/// - Prevents double-booking (assigning to busy drivers)
/// - Enables driver work shift management
/// - Supports real-time driver dashboard
/// - Type-safe availability transitions
///
/// **Availability Workflow:**
/// ```
/// offline → available (driver starts work shift)
/// available → busy (driver accepts order)
/// busy → available (driver completes delivery)
/// available → offline (driver ends shift)
/// ```
///
/// **Business Logic:**
/// - Only available drivers can accept new orders
/// - Busy drivers are currently handling an order
/// - Offline drivers are not working (invisible to order assignment)
/// - Driver location tracking only when online (available or busy)
///
/// **Usage Example:**
/// ```dart
/// // Driver starts work
/// final onlineDriver = driver.copyWith(
///   availability: AvailabilityStatus.available,
///   currentLocation: gpsLocation,
/// );
///
/// // Driver accepts order
/// final busyDriver = driver.copyWith(
///   availability: AvailabilityStatus.busy,
/// );
///
/// // Check if can accept orders
/// if (driver.availability.canAcceptOrders) {
///   showOrderNotification();
/// }
///
/// // Driver goes offline
/// final offlineDriver = driver.copyWith(
///   availability: AvailabilityStatus.offline,
///   currentLocation: null,
/// );
/// ```
///
/// **IMPROVEMENT:**
/// - [Medium Priority] Add on_break status (driver temporarily unavailable)
/// - [Low Priority] Add scheduled status (driver pre-scheduled to work)
enum AvailabilityStatus {
  /// Driver is offline (not working)
  offline,

  /// Driver is online and available for new orders
  available,

  /// Driver is online but currently handling an order
  busy,
}

/// [AvailabilityStatusExtension] - Extension methods for AvailabilityStatus enum
///
/// **What it provides:**
/// - JSON serialization (toJson)
/// - User-friendly display names (displayName)
/// - Availability queries (isOnline, canAcceptOrders)
///
/// **Usage Example:**
/// ```dart
/// final status = AvailabilityStatus.available;
/// print(status.toJson()); // 'available'
/// print(status.displayName); // 'Available'
/// print(status.isOnline); // true
/// print(status.canAcceptOrders); // true
/// ```
extension AvailabilityStatusExtension on AvailabilityStatus {
  /// Converts enum to JSON string for API communication
  ///
  /// **Returns:** Lowercase string representation
  /// **Usage:** Serialization to backend API, local database
  ///
  /// **Examples:**
  /// - AvailabilityStatus.offline → 'offline'
  /// - AvailabilityStatus.available → 'available'
  /// - AvailabilityStatus.busy → 'busy'
  String toJson() {
    switch (this) {
      case AvailabilityStatus.offline:
        return 'offline';
      case AvailabilityStatus.available:
        return 'available';
      case AvailabilityStatus.busy:
        return 'busy';
    }
  }

  /// Returns user-friendly display name for UI presentation
  ///
  /// **Returns:** Capitalized status name
  /// **Usage:** Status badges, driver dashboard, admin panel
  ///
  /// **Examples:**
  /// - AvailabilityStatus.offline → 'Offline'
  /// - AvailabilityStatus.available → 'Available'
  /// - AvailabilityStatus.busy → 'Busy'
  String get displayName {
    switch (this) {
      case AvailabilityStatus.offline:
        return 'Offline';
      case AvailabilityStatus.available:
        return 'Available';
      case AvailabilityStatus.busy:
        return 'Busy';
    }
  }

  /// Returns true if driver is online (available or busy)
  ///
  /// **What it checks:**
  /// - Available: true (online and ready for orders)
  /// - Busy: true (online but handling current order)
  /// - Offline: false (not working)
  ///
  /// **Use cases:**
  /// - Show "Online" indicator in UI
  /// - Enable location tracking (only for online drivers)
  /// - Filter online drivers in admin dashboard
  /// - Calculate active driver count
  ///
  /// **Returns:** true if available OR busy, false if offline
  bool get isOnline =>
      this == AvailabilityStatus.available || this == AvailabilityStatus.busy;

  /// Returns true if driver can accept new orders
  ///
  /// **What it checks:**
  /// - Available: true (ready for orders)
  /// - Busy: false (already handling an order)
  /// - Offline: false (not working)
  ///
  /// **Use cases:**
  /// - Filter drivers for order assignment
  /// - Show "Accept Order" button in driver app
  /// - Enable push notifications for new orders
  /// - Calculate available driver count
  ///
  /// **Returns:** true only if availability is available
  bool get canAcceptOrders => this == AvailabilityStatus.available;
}

/// [AvailabilityStatusHelper] - Helper class for AvailabilityStatus deserialization
///
/// **What it does:**
/// - Parses string values to AvailabilityStatus enum
/// - Handles case-insensitive parsing
/// - Validates availability values
///
/// **Usage Example:**
/// ```dart
/// // Parse from API response
/// final status = AvailabilityStatusHelper.fromString('available');
///
/// // Case-insensitive
/// final status2 = AvailabilityStatusHelper.fromString('BUSY');
///
/// // Invalid status throws error
/// try {
///   final invalid = AvailabilityStatusHelper.fromString('unknown');
/// } catch (e) {
///   print('Invalid status: $e'); // ArgumentError
/// }
/// ```
class AvailabilityStatusHelper {
  /// Parses availability status from string (case-insensitive)
  ///
  /// **Parameters:**
  /// - [value]: Status string (e.g., 'offline', 'available', 'BUSY')
  ///
  /// **Returns:** Corresponding AvailabilityStatus enum value
  ///
  /// **Throws:**
  /// - ArgumentError: If value is not a valid availability status
  ///
  /// **Supported values:**
  /// - 'offline' → AvailabilityStatus.offline
  /// - 'available' → AvailabilityStatus.available
  /// - 'busy' → AvailabilityStatus.busy
  static AvailabilityStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'offline':
        return AvailabilityStatus.offline;
      case 'available':
        return AvailabilityStatus.available;
      case 'busy':
        return AvailabilityStatus.busy;
      default:
        throw ArgumentError('Invalid availability status: $value');
    }
  }
}
