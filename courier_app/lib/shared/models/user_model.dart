import 'package:delivery_app/features/auth/domain/entities/user.dart';
import 'package:delivery_app/features/auth/domain/entities/user_status.dart';
import 'package:delivery_app/features/auth/domain/entities/user_role.dart';
import 'package:delivery_app/shared/domain/value_objects/email.dart';
import 'package:delivery_app/shared/domain/value_objects/entity_id.dart';
import 'package:delivery_app/shared/domain/value_objects/phone_number.dart';

/// Data model for User that handles JSON serialization
/// This model is shared across features as user information is needed
/// in customer, driver, and profile management features
class UserModel extends User {
  UserModel({
    required super.id,
    required super.firstName,
    required super.lastName,
    required super.email,
    required super.phone,
    required super.status,
    required super.role,
    super.driverData,
    super.customerData,
    required super.createdAt,
    required super.updatedAt,
  });

  /// Creates a UserModel from JSON data
  factory UserModel.fromJson(Map<String, dynamic> json) {
    final roleType = UserRoleTypeExtension.fromString(json['role'] as String);

    return UserModel(
      id: EntityID(json['id'] as String),
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      email: Email(json['email'] as String),
      phone: PhoneNumber(json['phone'] as String),
      status: UserStatusExtension.fromString(json['status'] as String),
      role: UserRole(
        type: roleType,
        permissions: (json['permissions'] as List<dynamic>?)?.cast<String>() ??
            (roleType == UserRoleType.customer
                ? UserRole.customer().permissions
                : UserRole.driver().permissions),
        assignedAt: json['role_assigned_at'] != null
            ? DateTime.parse(json['role_assigned_at'] as String)
            : DateTime.now(),
      ),
      driverData: roleType == UserRoleType.driver && json['driver_data'] != null
          ? _parseDriverData(json['driver_data'] as Map<String, dynamic>)
          : (roleType == UserRoleType.driver ? const DriverData() : null),
      customerData: roleType == UserRoleType.customer &&
              json['customer_data'] != null
          ? _parseCustomerData(json['customer_data'] as Map<String, dynamic>)
          : (roleType == UserRoleType.customer ? const CustomerData() : null),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  static DriverData _parseDriverData(Map<String, dynamic> json) => DriverData(
        vehicleType: json['vehicle_type'] as String?,
        vehicleNumber: json['vehicle_number'] as String?,
        licenseNumber: json['license_number'] as String?,
        isAvailable: json['is_available'] as bool? ?? false,
        rating: (json['rating'] as num?)?.toDouble(),
        completedDeliveries: json['completed_deliveries'] as int? ?? 0,
        lastLocationUpdate: json['last_location_update'] != null
            ? DateTime.parse(json['last_location_update'] as String)
            : null,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );

  static CustomerData _parseCustomerData(Map<String, dynamic> json) =>
      CustomerData(
        savedAddresses:
            (json['saved_addresses'] as List<dynamic>?)?.cast<String>() ?? [],
        preferredPaymentMethod: json['preferred_payment_method'] as String?,
        totalOrders: json['total_orders'] as int? ?? 0,
        rating: (json['rating'] as num?)?.toDouble(),
      );

  /// Converts the UserModel to JSON
  Map<String, dynamic> toJson() => {
        'id': id.value,
        'first_name': firstName,
        'last_name': lastName,
        'email': email.value,
        'phone': phone.value,
        'status': status.value,
        'role': role.type.value,
        'permissions': role.permissions,
        'role_assigned_at': role.assignedAt.toIso8601String(),
        if (driverData != null)
          'driver_data': {
            'vehicle_type': driverData!.vehicleType,
            'vehicle_number': driverData!.vehicleNumber,
            'license_number': driverData!.licenseNumber,
            'is_available': driverData!.isAvailable,
            'rating': driverData!.rating,
            'completed_deliveries': driverData!.completedDeliveries,
            'last_location_update':
                driverData!.lastLocationUpdate?.toIso8601String(),
            'latitude': driverData!.latitude,
            'longitude': driverData!.longitude,
          },
        if (customerData != null)
          'customer_data': {
            'saved_addresses': customerData!.savedAddresses,
            'preferred_payment_method': customerData!.preferredPaymentMethod,
            'total_orders': customerData!.totalOrders,
            'rating': customerData!.rating,
          },
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  /// Creates a UserModel from a User entity
  factory UserModel.fromEntity(User user) => UserModel(
        id: user.id,
        firstName: user.firstName,
        lastName: user.lastName,
        email: user.email,
        phone: user.phone,
        status: user.status,
        role: user.role,
        driverData: user.driverData,
        customerData: user.customerData,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt,
      );
}
