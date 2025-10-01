/// Driver verification status for Nigerian courier service
///
/// Defines the approval states for driver accounts
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

extension DriverStatusExtension on DriverStatus {
  /// Convert enum to JSON string
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

  /// Get user-friendly display name
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

/// Helper class for DriverStatus parsing
class DriverStatusHelper {
  /// Parse driver status from string
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
