import 'package:equatable/equatable.dart';
import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:delivery_app/shared/domain/value_objects/entity_id.dart';
import 'package:delivery_app/shared/domain/value_objects/email.dart';
import 'package:delivery_app/shared/domain/value_objects/phone_number.dart';
import 'package:delivery_app/features/auth/domain/entities/user_status.dart';

/// User domain entity representing an authenticated user
class User extends Equatable {
  final EntityID id;
  final String firstName;
  final String lastName;
  final Email email;
  final PhoneNumber phone;
  final UserStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Creates a User entity with validation
  User({
    required this.id,
    required String firstName,
    required String lastName,
    required this.email,
    required this.phone,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  })  : firstName = _validateFirstName(firstName),
        lastName = _validateLastName(lastName);

  /// Validates first name according to business rules
  static String _validateFirstName(String firstName) {
    if (firstName.isEmpty) {
      throw ArgumentError(AppStrings.errorFirstNameEmpty);
    }

    final trimmed = firstName.trim();
    if (trimmed.length < 2) {
      throw ArgumentError(AppStrings.errorFirstNameTooShort);
    }

    if (trimmed.length > 50) {
      throw ArgumentError(AppStrings.errorFirstNameTooLong);
    }

    return trimmed;
  }

  /// Validates last name according to business rules
  static String _validateLastName(String lastName) {
    if (lastName.isEmpty) {
      throw ArgumentError(AppStrings.errorLastNameEmpty);
    }

    final trimmed = lastName.trim();
    if (trimmed.length < 2) {
      throw ArgumentError(AppStrings.errorLastNameTooShort);
    }

    if (trimmed.length > 50) {
      throw ArgumentError(AppStrings.errorLastNameTooLong);
    }

    return trimmed;
  }

  /// Get the full name of the user
  String get fullName => '$firstName $lastName';

  /// Check if the user account is active
  bool get isActive => status == UserStatus.active;

  /// Creates a copy of this user with the specified fields replaced
  User copyWith({
    EntityID? id,
    String? firstName,
    String? lastName,
    Email? email,
    PhoneNumber? phone,
    UserStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(), // Always update the timestamp
    );
  }

  @override
  List<Object> get props => [id]; // Equality based on ID only

  @override
  String toString() {
    return 'User(id: $id, name: $fullName, email: $email, status: $status)';
  }
}