/// Driver availability status for Nigerian courier service
///
/// Defines whether a driver is online and available for orders
enum AvailabilityStatus {
  /// Driver is offline (not working)
  offline,

  /// Driver is online and available for new orders
  available,

  /// Driver is online but currently handling an order
  busy,
}

extension AvailabilityStatusExtension on AvailabilityStatus {
  /// Convert enum to JSON string
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

  /// Get user-friendly display name
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

  /// Check if driver is online (available or busy)
  bool get isOnline =>
      this == AvailabilityStatus.available || this == AvailabilityStatus.busy;

  /// Check if driver can accept new orders
  bool get canAcceptOrders => this == AvailabilityStatus.available;
}

/// Helper class for AvailabilityStatus parsing
class AvailabilityStatusHelper {
  /// Parse availability status from string
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
