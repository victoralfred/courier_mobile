import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_app/features/auth/domain/entities/pkce_challenge.dart';

void main() {
  group('PKCEChallenge', () {
    late PKCEChallenge pkceChallenge;
    late DateTime testCreatedAt;

    setUp(() {
      testCreatedAt = DateTime.now();
      pkceChallenge = PKCEChallenge(
        codeVerifier: 'test-verifier-string-with-43-characters-minimum',
        codeChallenge: 'test-challenge-base64url-encoded',
        method: 'S256',
        createdAt: testCreatedAt,
      );
    });

    group('constructor', () {
      test('should create instance with all required properties', () {
        // Assert
        expect(pkceChallenge.codeVerifier,
            equals('test-verifier-string-with-43-characters-minimum'));
        expect(pkceChallenge.codeChallenge,
            equals('test-challenge-base64url-encoded'));
        expect(pkceChallenge.method, equals('S256'));
        expect(pkceChallenge.createdAt, equals(testCreatedAt));
      });
    });

    group('isExpired', () {
      test('should return false when created recently', () {
        // Arrange
        final recentChallenge = PKCEChallenge(
          codeVerifier: 'verifier',
          codeChallenge: 'challenge',
          method: 'S256',
          createdAt: DateTime.now(),
        );

        // Assert
        expect(recentChallenge.isExpired, isFalse);
      });

      test('should return false when created 9 minutes ago', () {
        // Arrange
        final validChallenge = PKCEChallenge(
          codeVerifier: 'verifier',
          codeChallenge: 'challenge',
          method: 'S256',
          createdAt: DateTime.now().subtract(const Duration(minutes: 9)),
        );

        // Assert
        expect(validChallenge.isExpired, isFalse);
      });

      test('should return true when created 11 minutes ago', () {
        // Arrange
        final expiredChallenge = PKCEChallenge(
          codeVerifier: 'verifier',
          codeChallenge: 'challenge',
          method: 'S256',
          createdAt: DateTime.now().subtract(const Duration(minutes: 11)),
        );

        // Assert
        expect(expiredChallenge.isExpired, isTrue);
      });

      test('should return true when created exactly 10 minutes ago', () {
        // Arrange
        final boundaryChallenge = PKCEChallenge(
          codeVerifier: 'verifier',
          codeChallenge: 'challenge',
          method: 'S256',
          createdAt: DateTime.now().subtract(
            const Duration(minutes: 10, seconds: 1),
          ),
        );

        // Assert
        expect(boundaryChallenge.isExpired, isTrue);
      });
    });

    group('copyWith', () {
      test('should create copy with updated codeVerifier', () {
        // Arrange
        const newVerifier = 'new-verifier-string-with-sufficient-length';

        // Act
        final copied = pkceChallenge.copyWith(codeVerifier: newVerifier);

        // Assert
        expect(copied.codeVerifier, equals(newVerifier));
        expect(copied.codeChallenge, equals(pkceChallenge.codeChallenge));
        expect(copied.method, equals(pkceChallenge.method));
        expect(copied.createdAt, equals(pkceChallenge.createdAt));
      });

      test('should create copy with updated codeChallenge', () {
        // Arrange
        const newChallenge = 'new-challenge-base64url';

        // Act
        final copied = pkceChallenge.copyWith(codeChallenge: newChallenge);

        // Assert
        expect(copied.codeVerifier, equals(pkceChallenge.codeVerifier));
        expect(copied.codeChallenge, equals(newChallenge));
        expect(copied.method, equals(pkceChallenge.method));
        expect(copied.createdAt, equals(pkceChallenge.createdAt));
      });

      test('should create copy with updated method', () {
        // Arrange
        const newMethod = 'plain';

        // Act
        final copied = pkceChallenge.copyWith(method: newMethod);

        // Assert
        expect(copied.codeVerifier, equals(pkceChallenge.codeVerifier));
        expect(copied.codeChallenge, equals(pkceChallenge.codeChallenge));
        expect(copied.method, equals(newMethod));
        expect(copied.createdAt, equals(pkceChallenge.createdAt));
      });

      test('should create copy with updated createdAt', () {
        // Arrange
        final newCreatedAt = DateTime.now().add(const Duration(days: 1));

        // Act
        final copied = pkceChallenge.copyWith(createdAt: newCreatedAt);

        // Assert
        expect(copied.codeVerifier, equals(pkceChallenge.codeVerifier));
        expect(copied.codeChallenge, equals(pkceChallenge.codeChallenge));
        expect(copied.method, equals(pkceChallenge.method));
        expect(copied.createdAt, equals(newCreatedAt));
      });

      test('should return same instance when no parameters provided', () {
        // Act
        final copied = pkceChallenge.copyWith();

        // Assert
        expect(copied.codeVerifier, equals(pkceChallenge.codeVerifier));
        expect(copied.codeChallenge, equals(pkceChallenge.codeChallenge));
        expect(copied.method, equals(pkceChallenge.method));
        expect(copied.createdAt, equals(pkceChallenge.createdAt));
      });
    });

    group('equality', () {
      test('should be equal when all properties are the same', () {
        // Arrange
        final challenge1 = PKCEChallenge(
          codeVerifier: 'verifier',
          codeChallenge: 'challenge',
          method: 'S256',
          createdAt: testCreatedAt,
        );

        final challenge2 = PKCEChallenge(
          codeVerifier: 'verifier',
          codeChallenge: 'challenge',
          method: 'S256',
          createdAt: testCreatedAt,
        );

        // Assert
        expect(challenge1, equals(challenge2));
        expect(challenge1.hashCode, equals(challenge2.hashCode));
      });

      test('should not be equal when codeVerifier differs', () {
        // Arrange
        final challenge1 = PKCEChallenge(
          codeVerifier: 'verifier1',
          codeChallenge: 'challenge',
          method: 'S256',
          createdAt: testCreatedAt,
        );

        final challenge2 = PKCEChallenge(
          codeVerifier: 'verifier2',
          codeChallenge: 'challenge',
          method: 'S256',
          createdAt: testCreatedAt,
        );

        // Assert
        expect(challenge1, isNot(equals(challenge2)));
      });

      test('should not be equal when codeChallenge differs', () {
        // Arrange
        final challenge1 = PKCEChallenge(
          codeVerifier: 'verifier',
          codeChallenge: 'challenge1',
          method: 'S256',
          createdAt: testCreatedAt,
        );

        final challenge2 = PKCEChallenge(
          codeVerifier: 'verifier',
          codeChallenge: 'challenge2',
          method: 'S256',
          createdAt: testCreatedAt,
        );

        // Assert
        expect(challenge1, isNot(equals(challenge2)));
      });

      test('should not be equal when method differs', () {
        // Arrange
        final challenge1 = PKCEChallenge(
          codeVerifier: 'verifier',
          codeChallenge: 'challenge',
          method: 'S256',
          createdAt: testCreatedAt,
        );

        final challenge2 = PKCEChallenge(
          codeVerifier: 'verifier',
          codeChallenge: 'challenge',
          method: 'plain',
          createdAt: testCreatedAt,
        );

        // Assert
        expect(challenge1, isNot(equals(challenge2)));
      });

      test('should not be equal when createdAt differs', () {
        // Arrange
        final challenge1 = PKCEChallenge(
          codeVerifier: 'verifier',
          codeChallenge: 'challenge',
          method: 'S256',
          createdAt: testCreatedAt,
        );

        final challenge2 = PKCEChallenge(
          codeVerifier: 'verifier',
          codeChallenge: 'challenge',
          method: 'S256',
          createdAt: testCreatedAt.add(const Duration(seconds: 1)),
        );

        // Assert
        expect(challenge1, isNot(equals(challenge2)));
      });
    });

    group('toString', () {
      test('should return string representation with method and createdAt', () {
        // Act
        final str = pkceChallenge.toString();

        // Assert
        expect(str, contains('PKCEChallenge'));
        expect(str, contains('S256'));
        expect(str, contains(testCreatedAt.toString()));
      });

      test('should not include sensitive data in toString', () {
        // Act
        final str = pkceChallenge.toString();

        // Assert
        expect(str.contains(pkceChallenge.codeVerifier), isFalse);
        expect(str.contains(pkceChallenge.codeChallenge), isFalse);
      });
    });
  });
}