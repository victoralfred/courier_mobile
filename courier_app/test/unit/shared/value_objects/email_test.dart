import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_app/shared/domain/value_objects/email.dart';

void main() {
  group('Email', () {
    group('validation', () {
      test('should create Email with valid email address', () {
        // Arrange
        const validEmail = 'john.doe@example.com';

        // Act
        final email = Email(validEmail);

        // Assert
        expect(email.value, equals(validEmail.toLowerCase()));
      });

      test('should convert email to lowercase', () {
        // Arrange
        const mixedCaseEmail = 'John.Doe@Example.COM';

        // Act
        final email = Email(mixedCaseEmail);

        // Assert
        expect(email.value, equals('john.doe@example.com'));
      });

      test('should accept emails with subdomains', () {
        // Arrange
        const emailWithSubdomain = 'user@mail.example.com';

        // Act
        final email = Email(emailWithSubdomain);

        // Assert
        expect(email.value, equals(emailWithSubdomain));
      });

      test('should accept emails with plus sign', () {
        // Arrange
        const emailWithPlus = 'user+tag@example.com';

        // Act
        final email = Email(emailWithPlus);

        // Assert
        expect(email.value, equals(emailWithPlus));
      });

      test('should throw ArgumentError for invalid email format', () {
        // Arrange
        const invalidEmails = [
          'not-an-email',
          'missing@domain',
          '@nodomain.com',
          'no-at-sign.com',
          'double@@domain.com',
          'spaces in@email.com',
          'trailing.dot@domain.com.',
        ];

        // Act & Assert
        for (final invalidEmail in invalidEmails) {
          expect(
            () => Email(invalidEmail),
            throwsA(isA<ArgumentError>()),
            reason: 'Should reject: $invalidEmail',
          );
        }
      });

      test('should throw ArgumentError for empty string', () {
        // Arrange
        const emptyString = '';

        // Act & Assert
        expect(
          () => Email(emptyString),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw ArgumentError for whitespace only', () {
        // Arrange
        const whitespaceOnly = '   ';

        // Act & Assert
        expect(
          () => Email(whitespaceOnly),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('domain extraction', () {
      test('should extract domain from email', () {
        // Arrange
        final email = Email('user@example.com');

        // Act
        final domain = email.domain;

        // Assert
        expect(domain, equals('example.com'));
      });

      test('should extract domain with subdomain', () {
        // Arrange
        final email = Email('user@mail.example.com');

        // Act
        final domain = email.domain;

        // Assert
        expect(domain, equals('mail.example.com'));
      });
    });

    group('equality', () {
      test('should be equal for same email value', () {
        // Arrange
        const emailString = 'john@example.com';
        final email1 = Email(emailString);
        final email2 = Email(emailString);

        // Assert
        expect(email1, equals(email2));
        expect(email1.hashCode, equals(email2.hashCode));
      });

      test('should be equal for same email in different cases', () {
        // Arrange
        final email1 = Email('John@Example.COM');
        final email2 = Email('john@example.com');

        // Assert
        expect(email1, equals(email2));
        expect(email1.hashCode, equals(email2.hashCode));
      });

      test('should not be equal for different email values', () {
        // Arrange
        final email1 = Email('john@example.com');
        final email2 = Email('jane@example.com');

        // Assert
        expect(email1, isNot(equals(email2)));
      });
    });

    group('string representation', () {
      test('should return email value as string', () {
        // Arrange
        const emailString = 'john@example.com';
        final email = Email(emailString);

        // Act
        final stringValue = email.toString();

        // Assert
        expect(stringValue, equals(emailString));
      });
    });
  });
}