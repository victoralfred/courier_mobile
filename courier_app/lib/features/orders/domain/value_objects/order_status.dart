/// Order status enumeration for Nigerian courier service
///
/// Defines the lifecycle states of a delivery order
enum OrderStatus {
  /// Order created, waiting for driver assignment
  pending,

  /// Order assigned to a driver, driver hasn't started pickup
  assigned,

  /// Driver is picking up the package
  pickup,

  /// Package picked up, driver in transit to delivery location
  inTransit,

  /// Order successfully delivered
  completed,

  /// Order cancelled by customer or system
  cancelled,
}

extension OrderStatusExtension on OrderStatus {
  /// Convert enum to JSON string
  String toJson() {
    switch (this) {
      case OrderStatus.pending:
        return 'pending';
      case OrderStatus.assigned:
        return 'assigned';
      case OrderStatus.pickup:
        return 'pickup';
      case OrderStatus.inTransit:
        return 'in_transit';
      case OrderStatus.completed:
        return 'completed';
      case OrderStatus.cancelled:
        return 'cancelled';
    }
  }

  /// Get user-friendly display name
  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.assigned:
        return 'Assigned';
      case OrderStatus.pickup:
        return 'Picking Up';
      case OrderStatus.inTransit:
        return 'In Transit';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Helper class for OrderStatus parsing
class OrderStatusHelper {
  /// Parse order status from string
  ///
  /// Supports both mobile and backend API format:
  /// - 'picked_up' maps to pickup
  /// - 'delivered' maps to completed
  static OrderStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
        return OrderStatus.pending;
      case 'assigned':
        return OrderStatus.assigned;
      case 'pickup':
      case 'picked_up': // Backend API format
        return OrderStatus.pickup;
      case 'in_transit':
        return OrderStatus.inTransit;
      case 'completed':
      case 'delivered': // Backend API format
        return OrderStatus.completed;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        throw ArgumentError('Invalid order status: $value');
    }
  }
}
