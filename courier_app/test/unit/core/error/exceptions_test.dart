import 'package:delivery_app/core/error/exceptions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ServerException', () {
    test('should create ServerException with error response', () {
      // Arrange
      const code = 'VALIDATION_ERROR';
      const message = 'Invalid input data';
      const details = 'Email format is incorrect';

      // Act
      final exception = ServerException(
        code: code,
        message: message,
        details: details,
      );

      // Assert
      expect(exception.code, equals(code));
      expect(exception.message, equals(message));
      expect(exception.details, equals(details));
      expect(exception.toString(), contains('ServerException'));
    });

    test('should create ServerException from API error response', () {
      // Arrange
      final apiResponse = {
        'success': false,
        'error': {
          'code': 'UNAUTHORIZED',
          'message': 'Invalid credentials',
          'details': 'Token has expired',
        },
      };

      // Act
      final exception = ServerException.fromJson(apiResponse['error'] as Map<String, dynamic>);

      // Assert
      expect(exception.code, equals('UNAUTHORIZED'));
      expect(exception.message, equals('Invalid credentials'));
      expect(exception.details, equals('Token has expired'));
    });
  });

  group('NetworkException', () {
    test('should create NetworkException for connection timeout', () {
      // Arrange
      const message = 'Connection timeout';

      // Act
      final exception = NetworkException(message: message);

      // Assert
      expect(exception.message, equals(message));
      expect(exception.toString(), contains('NetworkException'));
    });

    test('should create NetworkException for no internet connection', () {
      // Act
      final exception = NetworkException.noConnection();

      // Assert
      expect(exception.message, equals('No internet connection'));
    });
  });

  group('CacheException', () {
    test('should create CacheException for cache not found', () {
      // Arrange
      const key = 'user_profile';

      // Act
      final exception = CacheException.notFound(key);

      // Assert
      expect(exception.message, equals('Cache not found for key: $key'));
    });

    test('should create CacheException for expired cache', () {
      // Act
      final exception = CacheException.expired();

      // Assert
      expect(exception.message, equals('Cache has expired'));
    });
  });

  group('ValidationException', () {
    test('should create ValidationException with field errors', () {
      // Arrange
      final fieldErrors = {
        'email': 'Invalid email format',
        'phone': 'Phone number is required',
      };

      // Act
      final exception = ValidationException(fieldErrors: fieldErrors);

      // Assert
      expect(exception.fieldErrors, equals(fieldErrors));
      expect(exception.message, equals('Validation failed'));
    });

    test('should create ValidationException from API response', () {
      // Arrange
      final apiResponse = {
        'success': false,
        'error': {
          'code': 'VALIDATION_ERROR',
          'message': 'Input validation failed',
          'details': {
            'first_name': 'Must be at least 2 characters',
            'email': 'Invalid email format',
          },
        },
      };

      // Act
      final exception = ValidationException.fromJson(apiResponse['error'] as Map<String, dynamic>);

      // Assert
      expect(exception.fieldErrors['first_name'], equals('Must be at least 2 characters'));
      expect(exception.fieldErrors['email'], equals('Invalid email format'));
    });
  });

  group('AuthenticationException', () {
    test('should create AuthenticationException for unauthorized access', () {
      // Act
      final exception = AuthenticationException.unauthorized();

      // Assert
      expect(exception.message, equals('Unauthorized access'));
      expect(exception.code, equals('UNAUTHORIZED'));
    });

    test('should create AuthenticationException for session expired', () {
      // Act
      final exception = AuthenticationException.sessionExpired();

      // Assert
      expect(exception.message, equals('Session has expired'));
      expect(exception.code, equals('SESSION_EXPIRED'));
    });

    test('should create AuthenticationException for invalid credentials', () {
      // Act
      final exception = AuthenticationException.invalidCredentials();

      // Assert
      expect(exception.message, equals('Invalid credentials'));
      expect(exception.code, equals('INVALID_CREDENTIALS'));
    });
  });

  group('UnknownException', () {
    test('should create UnknownException for unexpected errors', () {
      // Arrange
      const message = 'An unexpected error occurred';

      // Act
      final exception = UnknownException(message: message);

      // Assert
      expect(exception.message, equals(message));
    });

    test('should create UnknownException with default message', () {
      // Act
      final exception = UnknownException();

      // Assert
      expect(exception.message, equals('An unknown error occurred'));
    });
  });
}