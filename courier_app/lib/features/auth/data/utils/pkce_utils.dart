import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import '../../../../core/constants/app_strings.dart';

/// Utility class for PKCE (Proof Key for Code Exchange) operations.
/// Implements RFC 7636 for OAuth2 security enhancement.
class PKCEUtils {
  /// Minimum length for code verifier as per RFC 7636
  static const int minVerifierLength = 43;

  /// Maximum length for code verifier as per RFC 7636
  static const int maxVerifierLength = 128;

  /// Characters allowed in code verifier (unreserved characters)
  static const String _verifierChars = AppStrings.pkceUnreservedChars;

  /// Generates a cryptographically secure code verifier.
  ///
  /// Returns a random string between 43 and 128 characters long,
  /// using only unreserved characters as defined in RFC 7636.
  static String generateCodeVerifier([int? length]) {
    final verifierLength = length ?? maxVerifierLength;

    if (verifierLength < minVerifierLength ||
        verifierLength > maxVerifierLength) {
      throw ArgumentError(
        AppStrings.format(
          AppStrings.errorOAuthCodeVerifierLength,
          {
            AppStrings.oauthFieldMin: minVerifierLength.toString(),
            AppStrings.oauthFieldMax: maxVerifierLength.toString()
          },
        ),
      );
    }

    final random = Random.secure();
    final codeVerifier = StringBuffer();

    for (int i = 0; i < verifierLength; i++) {
      final index = random.nextInt(_verifierChars.length);
      codeVerifier.write(_verifierChars[index]);
    }

    return codeVerifier.toString();
  }

  /// Generates a code challenge from a code verifier using SHA256.
  ///
  /// The challenge is the base64url-encoded SHA256 hash of the verifier.
  static String generateCodeChallenge(String codeVerifier) {
    if (codeVerifier.length < minVerifierLength ||
        codeVerifier.length > maxVerifierLength) {
      throw ArgumentError(
        AppStrings.format(
          AppStrings.errorOAuthInvalidVerifierLength,
          {
            AppStrings.oauthFieldMin: minVerifierLength.toString(),
            AppStrings.oauthFieldMax: maxVerifierLength.toString()
          },
        ),
      );
    }

    // Generate SHA256 hash
    final bytes = utf8.encode(codeVerifier);
    final digest = sha256.convert(bytes);

    // Convert to base64url without padding
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  /// Validates a code verifier against a code challenge.
  ///
  /// Returns true if the verifier matches the challenge when hashed.
  static bool validateChallenge(String codeVerifier, String codeChallenge) {
    try {
      final generatedChallenge = generateCodeChallenge(codeVerifier);
      return generatedChallenge == codeChallenge;
    } catch (e) {
      return false;
    }
  }

  /// Validates that a string is a valid code verifier.
  static bool isValidCodeVerifier(String verifier) {
    if (verifier.length < minVerifierLength ||
        verifier.length > maxVerifierLength) {
      return false;
    }

    // Check that all characters are unreserved
    final regex = RegExp(r'^[A-Za-z0-9\-._~]+$');
    return regex.hasMatch(verifier);
  }

  /// Generates a secure random state parameter for OAuth flows.
  ///
  /// The state parameter prevents CSRF attacks.
  static String generateState([int length = 32]) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  /// Generates a secure nonce for OpenID Connect flows.
  static String generateNonce([int length = 32]) => generateState(length);
}
