import 'package:equatable/equatable.dart';

/// [PKCEChallenge] - Domain entity representing PKCE (Proof Key for Code Exchange) challenge
///
/// **What it does:**
/// - Implements PKCE security extension for OAuth2 (RFC 7636)
/// - Generates cryptographically secure code verifier
/// - Creates SHA256 code challenge from verifier
/// - Prevents authorization code interception attacks
/// - Manages challenge lifecycle and expiry
/// - Immutable entity with copyWith pattern
///
/// **Why it exists:**
/// - Security: Prevents authorization code interception
/// - Required for public clients (mobile, SPA)
/// - Recommended for all OAuth2 clients
/// - Mitigates authorization code injection attacks
/// - No client secret needed (secure for mobile)
/// - Clean Architecture domain layer entity
///
/// **PKCE Flow:**
/// ```
/// [Generate Challenge]
///         |
///         v
/// code_verifier: random 43-128 char string
///         |
///         v
/// code_challenge: SHA256(code_verifier)
///         |
///         v
/// [Send challenge to provider]
///         |
///         v
/// [Provider stores challenge]
///         |
///         v
/// [User authorizes] --> [Auth code returned]
///         |
///         v
/// [Exchange code + verifier for token]
///         |
///         v
/// [Provider validates: SHA256(verifier) == stored challenge]
///         |
///         v
/// [Token issued if valid]
/// ```
///
/// **Security Benefits:**
/// - Prevents man-in-the-middle attacks
/// - Prevents malicious app intercepting auth codes
/// - Works without client secret
/// - Cryptographically secure
///
/// **Usage Example:**
/// ```dart
/// // Generate PKCE challenge
/// final pkce = PKCEChallenge.generate(); // Requires implementation
///
/// // Build authorization URL with challenge
/// final authUrl = provider.buildAuthorizationUrl(
///   state: state,
///   codeChallenge: pkce.codeChallenge,
///   codeChallengeMethod: pkce.method, // 'S256'
/// );
///
/// // User authorizes, receives auth code
/// final code = await handleCallback();
///
/// // Exchange code for token using verifier
/// final token = await exchangeCode(
///   code: code,
///   codeVerifier: pkce.codeVerifier, // Secret, never sent before
/// );
/// ```
///
/// **RFC 7636 Compliance:**
/// - Verifier: 43-128 characters, URL-safe
/// - Challenge: Base64URL(SHA256(verifier))
/// - Method: 'S256' (SHA256)
///
/// **IMPROVEMENT:**
/// - [High Priority] Add static generate() factory method
/// - [Medium Priority] Add configurable expiry duration
/// - [Medium Priority] Add verifier validation (length, characters)
/// - [Low Priority] Support 'plain' method (not recommended)
/// - [Low Priority] Add challenge validation
class PKCEChallenge extends Equatable {
  /// The code verifier - a cryptographically random string
  ///
  /// **Requirements (RFC 7636):**
  /// - Length: 43 to 128 characters
  /// - Characters: [A-Z] [a-z] [0-9] - . _ ~
  /// - Cryptographically random
  /// - URL-safe (no encoding needed)
  ///
  /// **Security:**
  /// - High entropy (unpredictable)
  /// - Kept secret until token exchange
  /// - Never sent to provider during authorization
  /// - Transmitted only during token exchange
  ///
  /// **Example:** dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk
  final String codeVerifier;

  /// The code challenge - a base64url-encoded SHA256 hash of the code verifier
  ///
  /// **Generation:** BASE64URL(SHA256(codeVerifier))
  ///
  /// **Characteristics:**
  /// - Derived from code verifier
  /// - One-way transformation (can't reverse to get verifier)
  /// - 43 characters (base64url-encoded SHA256)
  /// - URL-safe (no + / = characters)
  ///
  /// **Security:**
  /// - Sent to provider during authorization
  /// - Provider stores it
  /// - Used later to validate verifier
  ///
  /// **Example:** E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM
  final String codeChallenge;

  /// The method used to generate the challenge
  ///
  /// **Value:** 'S256' (SHA256)
  ///
  /// **Why S256:**
  /// - Cryptographically secure
  /// - One-way hash function
  /// - Standard hash algorithm
  /// - Better security than 'plain' method
  ///
  /// **Note:** RFC 7636 also defines 'plain' method (not recommended)
  final String method;

  /// The timestamp when this challenge was created
  ///
  /// **Use cases:**
  /// - Expiry validation
  /// - Prevent replay attacks
  /// - Track challenge age
  /// - Analytics on auth flow duration
  ///
  /// **Security:** Challenges should be time-limited
  final DateTime createdAt;

  /// Creates a PKCEChallenge with specified values
  ///
  /// **Parameters:**
  /// - [codeVerifier]: Random verifier string (required, 43-128 chars)
  /// - [codeChallenge]: SHA256 hash of verifier (required, base64url)
  /// - [method]: Hash method (required, should be 'S256')
  /// - [createdAt]: Creation timestamp (required)
  ///
  /// **Note:** Consider using a static generate() factory instead
  const PKCEChallenge({
    required this.codeVerifier,
    required this.codeChallenge,
    required this.method,
    required this.createdAt,
  });

  /// Checks if the PKCE challenge has expired
  ///
  /// **What it does:**
  /// - Calculates age of challenge
  /// - Compares against 10 minute threshold
  ///
  /// **Why 10 minutes:**
  /// - Balances security and UX
  /// - OAuth2 auth flows typically complete in 1-5 minutes
  /// - Prevents stale challenge reuse
  /// - Mitigates replay attacks
  ///
  /// **Returns:** true if challenge is 10+ minutes old
  ///
  /// **Use cases:**
  /// - Validate before token exchange
  /// - Cleanup expired challenges
  /// - Security checks
  ///
  /// **Example:**
  /// ```dart
  /// if (pkce.isExpired) {
  ///   throw PKCEChallengeExpiredError();
  /// }
  /// ```
  bool get isExpired {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    return difference.inMinutes >= 10;
  }

  /// Creates a copy of this PKCEChallenge with updated fields
  ///
  /// **What it does:**
  /// - Creates new PKCEChallenge with specified changes
  /// - Preserves unchanged fields
  /// - Maintains immutability
  ///
  /// **Parameters:** All optional, uses current value if not provided
  ///
  /// **Returns:** New PKCEChallenge instance with updates
  ///
  /// **Note:** Rarely needed; challenges are typically immutable once created
  ///
  /// **Example:**
  /// ```dart
  /// // Extend expiry (not recommended)
  /// final extended = pkce.copyWith(createdAt: DateTime.now());
  /// ```
  PKCEChallenge copyWith({
    String? codeVerifier,
    String? codeChallenge,
    String? method,
    DateTime? createdAt,
  }) =>
      PKCEChallenge(
        codeVerifier: codeVerifier ?? this.codeVerifier,
        codeChallenge: codeChallenge ?? this.codeChallenge,
        method: method ?? this.method,
        createdAt: createdAt ?? this.createdAt,
      );

  /// Equatable props - equality based on all fields
  @override
  List<Object?> get props => [
        codeVerifier,
        codeChallenge,
        method,
        createdAt,
      ];

  /// String representation for debugging
  ///
  /// **Format:** PKCEChallenge(method: ..., createdAt: ...)
  ///
  /// **Security:** Doesn't include verifier or challenge to prevent leaks
  @override
  String toString() => 'PKCEChallenge(method: $method, createdAt: $createdAt)';
}
