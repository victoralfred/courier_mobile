import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_app/features/auth/domain/entities/user.dart';
import 'package:delivery_app/features/auth/domain/entities/user_status.dart';
import 'package:delivery_app/features/auth/domain/entities/user_role.dart';
import 'package:delivery_app/shared/domain/value_objects/entity_id.dart';
import 'package:delivery_app/shared/domain/value_objects/email.dart';
import 'package:delivery_app/shared/domain/value_objects/phone_number.dart';

void main() {
  group('User Entity', () {
    group('constructor', () {
      test('should create User with all required fields', () {
        // Arrange
        final id = EntityID.generate();
        const firstName = 'John';
        const lastName = 'Doe';
        final email = Email('john.doe@example.com');
        final phone = PhoneNumber('+2348031234567');
        const status = UserStatus.active;
        final createdAt = DateTime.now();
        final updatedAt = DateTime.now();

        // Act
        final user = User(
          id: id,
          firstName: firstName,
          lastName: lastName,
          email: email,
          phone: phone,
          status: status,
          role: UserRole.customer(),
          customerData: const CustomerData(),
          createdAt: createdAt,
          updatedAt: updatedAt,
        );

        // Assert
        expect(user.id, equals(id));
        expect(user.firstName, equals(firstName));
        expect(user.lastName, equals(lastName));
        expect(user.email, equals(email));
        expect(user.phone, equals(phone));
        expect(user.status, equals(status));
        expect(user.createdAt, equals(createdAt));
        expect(user.updatedAt, equals(updatedAt));
      });

      test('should validate first name is not empty', () {
        // Arrange
        final id = EntityID.generate();
        const firstName = '';
        const lastName = 'Doe';
        final email = Email('john.doe@example.com');
        final phone = PhoneNumber('+2348031234567');

        // Act & Assert
        expect(
          () => User(
            id: id,
            firstName: firstName,
            lastName: lastName,
            email: email,
            phone: phone,
            status: UserStatus.active,
            role: UserRole.customer(),
          customerData: const CustomerData(),
          createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should validate last name is not empty', () {
        // Arrange
        final id = EntityID.generate();
        const firstName = 'John';
        const lastName = '';
        final email = Email('john.doe@example.com');
        final phone = PhoneNumber('+2348031234567');

        // Act & Assert
        expect(
          () => User(
            id: id,
            firstName: firstName,
            lastName: lastName,
            email: email,
            phone: phone,
            status: UserStatus.active,
            role: UserRole.customer(),
          customerData: const CustomerData(),
          createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should validate first name length constraints', () {
        // Arrange
        final id = EntityID.generate();
        const firstName = 'J'; // Too short (min 2)
        const lastName = 'Doe';
        final email = Email('john.doe@example.com');
        final phone = PhoneNumber('+2348031234567');

        // Act & Assert
        expect(
          () => User(
            id: id,
            firstName: firstName,
            lastName: lastName,
            email: email,
            phone: phone,
            status: UserStatus.active,
            role: UserRole.customer(),
          customerData: const CustomerData(),
          createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should validate last name length constraints', () {
        // Arrange
        final id = EntityID.generate();
        const firstName = 'John';
        const lastName = 'D'; // Too short (min 2)
        final email = Email('john.doe@example.com');
        final phone = PhoneNumber('+2348031234567');

        // Act & Assert
        expect(
          () => User(
            id: id,
            firstName: firstName,
            lastName: lastName,
            email: email,
            phone: phone,
            status: UserStatus.active,
            role: UserRole.customer(),
          customerData: const CustomerData(),
          createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('fullName', () {
      test('should return full name combining first and last name', () {
        // Arrange
        final user = User(
          id: EntityID.generate(),
          firstName: 'John',
          lastName: 'Doe',
          email: Email('john.doe@example.com'),
          phone: PhoneNumber('+2348031234567'),
          status: UserStatus.active,
          role: UserRole.customer(),
          customerData: const CustomerData(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        final fullName = user.fullName;

        // Assert
        expect(fullName, equals('John Doe'));
      });
    });

    group('isActive', () {
      test('should return true when user status is active', () {
        // Arrange
        final user = User(
          id: EntityID.generate(),
          firstName: 'John',
          lastName: 'Doe',
          email: Email('john.doe@example.com'),
          phone: PhoneNumber('+2348031234567'),
          status: UserStatus.active,
          role: UserRole.customer(),
          customerData: const CustomerData(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        final isActive = user.isActive;

        // Assert
        expect(isActive, isTrue);
      });

      test('should return false when user status is inactive', () {
        // Arrange
        final user = User(
          id: EntityID.generate(),
          firstName: 'John',
          lastName: 'Doe',
          email: Email('john.doe@example.com'),
          phone: PhoneNumber('+2348031234567'),
          status: UserStatus.inactive,
          role: UserRole.customer(),
          customerData: const CustomerData(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        final isActive = user.isActive;

        // Assert
        expect(isActive, isFalse);
      });
    });

    group('equality', () {
      test('should be equal when users have same id', () {
        // Arrange
        final id = EntityID.generate();
        final user1 = User(
          id: id,
          firstName: 'John',
          lastName: 'Doe',
          email: Email('john.doe@example.com'),
          phone: PhoneNumber('+2348031234567'),
          status: UserStatus.active,
          role: UserRole.customer(),
          customerData: const CustomerData(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final user2 = User(
          id: id,
          firstName: 'Jane',
          lastName: 'Smith',
          email: Email('jane.smith@example.com'),
          phone: PhoneNumber('+2348039876543'),
          status: UserStatus.inactive,
          role: UserRole.customer(),
          customerData: const CustomerData(),
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
        );

        // Assert
        expect(user1, equals(user2));
        expect(user1.hashCode, equals(user2.hashCode));
      });

      test('should not be equal when users have different ids', () {
        // Arrange
        final user1 = User(
          id: EntityID.generate(),
          firstName: 'John',
          lastName: 'Doe',
          email: Email('john.doe@example.com'),
          phone: PhoneNumber('+2348031234567'),
          status: UserStatus.active,
          role: UserRole.customer(),
          customerData: const CustomerData(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final user2 = User(
          id: EntityID.generate(),
          firstName: 'John',
          lastName: 'Doe',
          email: Email('john.doe@example.com'),
          phone: PhoneNumber('+2348031234567'),
          status: UserStatus.active,
          role: UserRole.customer(),
          customerData: const CustomerData(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Assert
        expect(user1, isNot(equals(user2)));
      });
    });

    group('copyWith', () {
      test('should create a copy with updated fields', () {
        // Arrange
        final original = User(
          id: EntityID.generate(),
          firstName: 'John',
          lastName: 'Doe',
          email: Email('john.doe@example.com'),
          phone: PhoneNumber('+2348031234567'),
          status: UserStatus.active,
          role: UserRole.customer(),
          customerData: const CustomerData(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Act
        final updated = original.copyWith(
          firstName: 'Jane',
          status: UserStatus.inactive,
        );

        // Assert
        expect(updated.firstName, equals('Jane'));
        expect(updated.lastName, equals(original.lastName));
        expect(updated.status, equals(UserStatus.inactive));
        expect(updated.id, equals(original.id));
        expect(updated.email, equals(original.email));
        expect(updated.phone, equals(original.phone));
      });

      test('should update updatedAt when copying', () {
        // Arrange
        final original = User(
          id: EntityID.generate(),
          firstName: 'John',
          lastName: 'Doe',
          email: Email('john.doe@example.com'),
          phone: PhoneNumber('+2348031234567'),
          status: UserStatus.active,
          role: UserRole.customer(),
          customerData: const CustomerData(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Wait a bit to ensure time difference
        final future = Future.delayed(const Duration(milliseconds: 10));

        // Act
        return future.then((_) {
          final updated = original.copyWith(firstName: 'Jane');

          // Assert
          expect(updated.updatedAt.isAfter(original.updatedAt), isTrue);
        });
      });
    });

    group('UserStatus', () {
      test('should have active and inactive statuses', () {
        // Assert
        expect(UserStatus.values, contains(UserStatus.active));
        expect(UserStatus.values, contains(UserStatus.inactive));
        expect(UserStatus.values.length, equals(2));
      });

      test('should convert to string correctly', () {
        // Assert
        expect(UserStatus.active.toString(), contains('active'));
        expect(UserStatus.inactive.toString(), contains('inactive'));
      });
    });
  });
}