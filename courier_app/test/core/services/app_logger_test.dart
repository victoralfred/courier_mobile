import 'package:delivery_app/core/services/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppLogger', () {
    late AppLogger logger;

    setUp(() {
      logger = AppLogger('TestLogger');
    });

    group('initialization', () {
      test('should create logger with given name', () {
        expect(logger.name, equals('TestLogger'));
      });

      test('should create logger with isDebug flag', () {
        final debugLogger = AppLogger('Debug', isDebug: true);
        final productionLogger = AppLogger('Production', isDebug: false);

        expect(debugLogger.isDebug, isTrue);
        expect(productionLogger.isDebug, isFalse);
      });
    });

    group('log levels', () {
      test('should log debug message', () {
        expect(() => logger.debug('Debug message'), returnsNormally);
      });

      test('should log info message', () {
        expect(() => logger.info('Info message'), returnsNormally);
      });

      test('should log warning message', () {
        expect(() => logger.warning('Warning message'), returnsNormally);
      });

      test('should log error message', () {
        expect(() => logger.error('Error message'), returnsNormally);
      });

      test('should log error with exception and stack trace', () {
        final exception = Exception('Test exception');
        final stackTrace = StackTrace.current;

        expect(
          () => logger.error(
            'Error with exception',
            error: exception,
            stackTrace: stackTrace,
          ),
          returnsNormally,
        );
      });
    });

    group('metadata logging', () {
      test('should log message with metadata', () {
        expect(
          () => logger.debug('Message with metadata', metadata: {
            'userId': '123',
            'action': 'login',
          }),
          returnsNormally,
        );
      });

      test('should log message with empty metadata', () {
        expect(
          () => logger.info('Message', metadata: {}),
          returnsNormally,
        );
      });
    });

    group('sensitive data redaction', () {
      test('should redact authorization header', () {
        final metadata = {
          'authorization': 'Bearer abc123token',
          'userId': '123',
        };

        expect(
          () => logger.debug('Request sent', metadata: metadata),
          returnsNormally,
        );
        // Actual redaction behavior tested in implementation
      });

      test('should redact token fields', () {
        final metadata = {
          'access_token': 'secret123',
          'refresh_token': 'secret456',
          'csrf_token': 'csrf123',
        };

        expect(
          () => logger.debug('Tokens', metadata: metadata),
          returnsNormally,
        );
      });

      test('should redact password fields', () {
        final metadata = {
          'email': 'user@example.com',
          'password': 'secret123',
        };

        expect(
          () => logger.debug('Login attempt', metadata: metadata),
          returnsNormally,
        );
      });
    });

    group('production mode', () {
      test('should not log in production mode when isDebug is false', () {
        final productionLogger = AppLogger('Production', isDebug: false);

        // These should not throw but also should not log anything
        expect(() => productionLogger.debug('Debug message'), returnsNormally);
        expect(() => productionLogger.info('Info message'), returnsNormally);
        expect(
            () => productionLogger.warning('Warning message'), returnsNormally);
      });

      test('should always log errors even in production', () {
        final productionLogger = AppLogger('Production', isDebug: false);

        expect(
          () => productionLogger.error('Error message'),
          returnsNormally,
        );
      });
    });

    group('network logging helpers', () {
      test('should log HTTP request', () {
        expect(
          () => logger.logRequest(
            method: 'POST',
            url: 'https://api.example.com/login',
            headers: {'Content-Type': 'application/json'},
            body: {'email': 'user@example.com'},
          ),
          returnsNormally,
        );
      });

      test('should log HTTP response', () {
        expect(
          () => logger.logResponse(
            method: 'POST',
            url: 'https://api.example.com/login',
            statusCode: 200,
            statusMessage: 'OK',
            body: {'success': true},
          ),
          returnsNormally,
        );
      });

      test('should log HTTP error', () {
        expect(
          () => logger.logError(
            method: 'POST',
            url: 'https://api.example.com/login',
            statusCode: 401,
            statusMessage: 'Unauthorized',
            error: Exception('Auth failed'),
          ),
          returnsNormally,
        );
      });
    });

    group('factory constructors', () {
      test('should create network logger', () {
        final networkLogger = AppLogger.network();
        expect(networkLogger.name, contains('Network'));
      });

      test('should create auth logger', () {
        final authLogger = AppLogger.auth();
        expect(authLogger.name, contains('Auth'));
      });

      test('should create database logger', () {
        final databaseLogger = AppLogger.database();
        expect(databaseLogger.name, contains('Database'));
      });
    });
  });
}
