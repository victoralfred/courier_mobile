import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_app/shared/domain/value_objects/phone_number.dart';

void main() {
  group('PhoneNumber', () {
    group('validation', () {
      test('should create PhoneNumber with valid international format', () {
        // Arrange
        const validPhoneNumbers = [
          '+1234567890',
          '+12345678901',
          '+123456789012',
          '+1234567890123',
          '+12345678901234',
          '+123456789012345',
          '+1234567890123456',
          '+12345678901234567',
          '+123456789012345678',
          '+1234567890123456789', // max 20 chars
        ];

        // Act & Assert
        for (final phoneString in validPhoneNumbers) {
          final phone = PhoneNumber(phoneString);
          expect(phone.value, equals(phoneString));
        }
      });

      test('should normalize phone number by removing spaces and dashes', () {
        // Arrange
        const phoneWithFormatting = '+1 234-567-8901';
        const expectedNormalized = '+12345678901';

        // Act
        final phone = PhoneNumber(phoneWithFormatting);

        // Assert
        expect(phone.value, equals(expectedNormalized));
      });

      test('should normalize phone number with parentheses', () {
        // Arrange
        const phoneWithParentheses = '+1 (234) 567-8901';
        const expectedNormalized = '+12345678901';

        // Act
        final phone = PhoneNumber(phoneWithParentheses);

        // Assert
        expect(phone.value, equals(expectedNormalized));
      });

      test('should throw ArgumentError for phone number without country code', () {
        // Arrange
        const phoneWithoutCountryCode = '2345678901';

        // Act & Assert
        expect(
          () => PhoneNumber(phoneWithoutCountryCode),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw ArgumentError for phone number too short', () {
        // Arrange
        const tooShortPhone = '+123456789'; // less than 10 digits

        // Act & Assert
        expect(
          () => PhoneNumber(tooShortPhone),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw ArgumentError for phone number too long', () {
        // Arrange
        const tooLongPhone = '+123456789012345678901'; // more than 20 chars

        // Act & Assert
        expect(
          () => PhoneNumber(tooLongPhone),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw ArgumentError for phone with letters', () {
        // Arrange
        const phoneWithLetters = '+1234567890ABC';

        // Act & Assert
        expect(
          () => PhoneNumber(phoneWithLetters),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw ArgumentError for empty string', () {
        // Arrange
        const emptyString = '';

        // Act & Assert
        expect(
          () => PhoneNumber(emptyString),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('country code extraction', () {
      test('should extract country code from phone number', () {
        // Arrange
        final testCases = [
          ('+1234567890123', '1'),
          ('+442345678901', '44'),
          ('+8612345678901', '86'),
          ('+972123456789', '972'),
        ];

        // Act & Assert
        for (final (phoneString, expectedCode) in testCases) {
          final phone = PhoneNumber(phoneString);
          expect(phone.countryCode, equals(expectedCode));
        }
      });
    });

    group('formatting', () {
      test('should format Nigerian mobile phone number', () {
        // Arrange
        final phone = PhoneNumber('+2348031234567');

        // Act
        final formatted = phone.formatInternational();

        // Assert
        expect(formatted, equals('+234 803 123 4567'));
      });

      test('should format Nigerian landline phone number', () {
        // Arrange
        final phone = PhoneNumber('+23412345678');

        // Act
        final formatted = phone.formatInternational();

        // Assert
        expect(formatted, equals('+234 12 3456 78'));
      });

      test('should format international number with generic pattern', () {
        // Arrange
        final phone = PhoneNumber('+12345678901');

        // Act
        final formatted = phone.formatInternational();

        // Assert
        expect(formatted, equals('+1 234 567 890 1'));
      });

      test('should return raw format', () {
        // Arrange
        const rawPhone = '+2348031234567';
        final phone = PhoneNumber(rawPhone);

        // Act
        final raw = phone.formatRaw();

        // Assert
        expect(raw, equals(rawPhone));
      });
    });

    group('equality', () {
      test('should be equal for same phone number value', () {
        // Arrange
        const phoneString = '+2348031234567';
        final phone1 = PhoneNumber(phoneString);
        final phone2 = PhoneNumber(phoneString);

        // Assert
        expect(phone1, equals(phone2));
        expect(phone1.hashCode, equals(phone2.hashCode));
      });

      test('should be equal for same phone with different formatting', () {
        // Arrange
        final phone1 = PhoneNumber('+234 803-123-4567');
        final phone2 = PhoneNumber('+2348031234567');

        // Assert
        expect(phone1, equals(phone2));
        expect(phone1.hashCode, equals(phone2.hashCode));
      });

      test('should not be equal for different phone numbers', () {
        // Arrange
        final phone1 = PhoneNumber('+2348031234567');
        final phone2 = PhoneNumber('+2348031234568');

        // Assert
        expect(phone1, isNot(equals(phone2)));
      });
    });

    group('string representation', () {
      test('should return phone number value as string', () {
        // Arrange
        const phoneString = '+2348031234567';
        final phone = PhoneNumber(phoneString);

        // Act
        final stringValue = phone.toString();

        // Assert
        expect(stringValue, equals(phoneString));
      });
    });
  });
}