import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_app/features/auth/data/utils/pkce_utils.dart';
import 'package:delivery_app/core/constants/app_strings.dart';

void main() {
  group('PKCEUtils', () {
    group('generateCodeVerifier', () {
      test('should generate code verifier with default length of 128', () {
        // Act
        final verifier = PKCEUtils.generateCodeVerifier();

        // Assert
        expect(verifier.length, equals(128));
        expect(PKCEUtils.isValidCodeVerifier(verifier), isTrue);
      });

      test('should generate code verifier with custom valid length', () {
        // Arrange
        const customLength = 64;

        // Act
        final verifier = PKCEUtils.generateCodeVerifier(customLength);

        // Assert
        expect(verifier.length, equals(customLength));
        expect(PKCEUtils.isValidCodeVerifier(verifier), isTrue);
      });

      test('should generate unique code verifiers', () {
        // Act
        final verifier1 = PKCEUtils.generateCodeVerifier();
        final verifier2 = PKCEUtils.generateCodeVerifier();

        // Assert
        expect(verifier1, isNot(equals(verifier2)));
      });

      test('should only use unreserved characters', () {
        // Arrange
        final regex = RegExp(r'^[A-Za-z0-9\-._~]+$');

        // Act
        final verifier = PKCEUtils.generateCodeVerifier();

        // Assert
        expect(regex.hasMatch(verifier), isTrue);
      });

      test('should throw ArgumentError for length less than minimum', () {
        // Arrange
        const invalidLength = 42;

        // Act & Assert
        expect(
          () => PKCEUtils.generateCodeVerifier(invalidLength),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('between'),
            ),
          ),
        );
      });

      test('should throw ArgumentError for length greater than maximum', () {
        // Arrange
        const invalidLength = 129;

        // Act & Assert
        expect(
          () => PKCEUtils.generateCodeVerifier(invalidLength),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('between'),
            ),
          ),
        );
      });
    });

    group('generateCodeChallenge', () {
      test('should generate valid base64url-encoded SHA256 challenge', () {
        // Arrange
        // Using a known test vector from RFC 7636
        const testVerifier =
            'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk';
        const expectedChallenge =
            'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM';

        // Act
        final challenge = PKCEUtils.generateCodeChallenge(testVerifier);

        // Assert
        expect(challenge, equals(expectedChallenge));
      });

      test('should generate challenge without padding characters', () {
        // Arrange
        final verifier = PKCEUtils.generateCodeVerifier();

        // Act
        final challenge = PKCEUtils.generateCodeChallenge(verifier);

        // Assert
        expect(challenge.contains('='), isFalse);
      });

      test('should throw ArgumentError for invalid verifier length', () {
        // Arrange
        const shortVerifier = 'tooShort';
        final longVerifier = 'a' * 129;

        // Act & Assert
        expect(
          () => PKCEUtils.generateCodeChallenge(shortVerifier),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => PKCEUtils.generateCodeChallenge(longVerifier),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should generate consistent challenge for same verifier', () {
        // Arrange
        final verifier = PKCEUtils.generateCodeVerifier();

        // Act
        final challenge1 = PKCEUtils.generateCodeChallenge(verifier);
        final challenge2 = PKCEUtils.generateCodeChallenge(verifier);

        // Assert
        expect(challenge1, equals(challenge2));
      });
    });

    group('validateChallenge', () {
      test('should return true for matching verifier and challenge', () {
        // Arrange
        final verifier = PKCEUtils.generateCodeVerifier();
        final challenge = PKCEUtils.generateCodeChallenge(verifier);

        // Act
        final isValid = PKCEUtils.validateChallenge(verifier, challenge);

        // Assert
        expect(isValid, isTrue);
      });

      test('should return false for non-matching verifier and challenge', () {
        // Arrange
        final verifier1 = PKCEUtils.generateCodeVerifier();
        final verifier2 = PKCEUtils.generateCodeVerifier();
        final challenge = PKCEUtils.generateCodeChallenge(verifier1);

        // Act
        final isValid = PKCEUtils.validateChallenge(verifier2, challenge);

        // Assert
        expect(isValid, isFalse);
      });

      test('should return false for invalid verifier', () {
        // Arrange
        const invalidVerifier = 'short';
        const challenge = 'someChallenge';

        // Act
        final isValid = PKCEUtils.validateChallenge(invalidVerifier, challenge);

        // Assert
        expect(isValid, isFalse);
      });
    });

    group('isValidCodeVerifier', () {
      test('should return true for valid code verifier', () {
        // Arrange
        final validVerifier = PKCEUtils.generateCodeVerifier();

        // Act
        final isValid = PKCEUtils.isValidCodeVerifier(validVerifier);

        // Assert
        expect(isValid, isTrue);
      });

      test('should return false for verifier with invalid characters', () {
        // Arrange
        final invalidVerifier = 'a' * 50 + '!@#\$%';

        // Act
        final isValid = PKCEUtils.isValidCodeVerifier(invalidVerifier);

        // Assert
        expect(isValid, isFalse);
      });

      test('should return false for verifier too short', () {
        // Arrange
        final shortVerifier = 'a' * 42;

        // Act
        final isValid = PKCEUtils.isValidCodeVerifier(shortVerifier);

        // Assert
        expect(isValid, isFalse);
      });

      test('should return false for verifier too long', () {
        // Arrange
        final longVerifier = 'a' * 129;

        // Act
        final isValid = PKCEUtils.isValidCodeVerifier(longVerifier);

        // Assert
        expect(isValid, isFalse);
      });

      test('should accept all unreserved characters', () {
        // Arrange
        const validVerifier =
            'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

        // Act
        final isValid = PKCEUtils.isValidCodeVerifier(validVerifier);

        // Assert
        expect(isValid, isTrue);
      });
    });

    group('generateState', () {
      test('should generate state with default length of 32', () {
        // Act
        final state = PKCEUtils.generateState();

        // Assert
        expect(state.isNotEmpty, isTrue);
        // Base64 encoding of 32 bytes results in ~43 characters
        expect(state.length, greaterThanOrEqualTo(32));
      });

      test('should generate state with custom length', () {
        // Arrange
        const customLength = 16;

        // Act
        final state = PKCEUtils.generateState(customLength);

        // Assert
        expect(state.isNotEmpty, isTrue);
      });

      test('should generate unique states', () {
        // Act
        final state1 = PKCEUtils.generateState();
        final state2 = PKCEUtils.generateState();

        // Assert
        expect(state1, isNot(equals(state2)));
      });

      test('should generate base64url-encoded state without padding', () {
        // Act
        final state = PKCEUtils.generateState();

        // Assert
        expect(state.contains('='), isFalse);
      });
    });

    group('generateNonce', () {
      test('should generate nonce with default length', () {
        // Act
        final nonce = PKCEUtils.generateNonce();

        // Assert
        expect(nonce.isNotEmpty, isTrue);
      });

      test('should generate nonce with custom length', () {
        // Arrange
        const customLength = 24;

        // Act
        final nonce = PKCEUtils.generateNonce(customLength);

        // Assert
        expect(nonce.isNotEmpty, isTrue);
      });

      test('should generate unique nonces', () {
        // Act
        final nonce1 = PKCEUtils.generateNonce();
        final nonce2 = PKCEUtils.generateNonce();

        // Assert
        expect(nonce1, isNot(equals(nonce2)));
      });

      test('should generate base64url-encoded nonce without padding', () {
        // Act
        final nonce = PKCEUtils.generateNonce();

        // Assert
        expect(nonce.contains('='), isFalse);
      });
    });
  });
}