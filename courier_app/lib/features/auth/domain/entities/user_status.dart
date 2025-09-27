/// User account status
enum UserStatus {
  /// User account is active and can perform all actions
  active,

  /// User account is inactive and restricted from certain actions
  inactive,
}

/// Extension methods for UserStatus
extension UserStatusExtension on UserStatus {
  /// Get string representation for API communication
  String get value {
    switch (this) {
      case UserStatus.active:
        return 'active';
      case UserStatus.inactive:
        return 'inactive';
    }
  }

  /// Create UserStatus from string value
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