import '../../features/auth/domain/entities/user.dart';
import '../../features/auth/domain/entities/user_status.dart';
import '../domain/value_objects/email.dart';
import '../domain/value_objects/entity_id.dart';
import '../domain/value_objects/phone_number.dart';

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
    required super.createdAt,
    required super.updatedAt,
  });

  /// Creates a UserModel from JSON data
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: EntityID(json['id'] as String),
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      email: Email(json['email'] as String),
      phone: PhoneNumber(json['phone'] as String),
      status: UserStatusExtension.fromString(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Converts the UserModel to JSON
  Map<String, dynamic> toJson() => {
        'id': id.value,
        'first_name': firstName,
        'last_name': lastName,
        'email': email.value,
        'phone': phone.value,
        'status': status.value,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  /// Creates a UserModel from a User entity
  factory UserModel.fromEntity(User user) {
    return UserModel(
      id: user.id,
      firstName: user.firstName,
      lastName: user.lastName,
      email: user.email,
      phone: user.phone,
      status: user.status,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    );
  }
}