import 'package:equatable/equatable.dart';
import 'package:delivery_app/core/constants/app_strings.dart';

/// Represents the role of a user in the system
enum UserRoleType {
  customer,
  driver,
  admin,
}

/// Extension methods for UserRoleType
extension UserRoleTypeExtension on UserRoleType {
  /// Get the display name for the role
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

/// User role entity with permissions
class UserRole extends Equatable {
  final UserRoleType type;
  final List<String> permissions;
  final DateTime assignedAt;

  const UserRole({
    required this.type,
    required this.permissions,
    required this.assignedAt,
  });

  /// Check if the role has a specific permission
  bool hasPermission(String permission) => permissions.contains(permission);

  /// Create a Customer role with default permissions
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

  @override
  List<Object> get props => [type, permissions, assignedAt];

  @override
  String toString() =>
      'UserRole(type: $type, permissions: ${permissions.length})';
}

/// Driver-specific data
class DriverData extends Equatable {
  final String? vehicleType;
  final String? vehicleNumber;
  final String? licenseNumber;
  final bool isAvailable;
  final double? rating;
  final int completedDeliveries;
  final DateTime? lastLocationUpdate;
  final double? latitude;
  final double? longitude;

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

/// Customer-specific data
class CustomerData extends Equatable {
  final List<String> savedAddresses;
  final String? preferredPaymentMethod;
  final int totalOrders;
  final double? rating;

  const CustomerData({
    this.savedAddresses = const [],
    this.preferredPaymentMethod,
    this.totalOrders = 0,
    this.rating,
  });

  /// Create a copy with updated fields
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

  @override
  List<Object?> get props => [
        savedAddresses,
        preferredPaymentMethod,
        totalOrders,
        rating,
      ];
}
