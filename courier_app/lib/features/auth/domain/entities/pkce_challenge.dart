import 'package:equatable/equatable.dart';

/// Represents a PKCE (Proof Key for Code Exchange) challenge
/// used for OAuth2 authorization flows as defined in RFC 7636.
class PKCEChallenge extends Equatable {
  /// The code verifier - a cryptographically random string
  /// between 43 and 128 characters in length.
  final String codeVerifier;

  /// The code challenge - a base64url-encoded SHA256 hash
  /// of the code verifier.
  final String codeChallenge;

  /// The method used to generate the challenge (always 'S256' for SHA256).
  final String method;

  /// The timestamp when this challenge was created.
  /// Used for expiry validation.
  final DateTime createdAt;

  const PKCEChallenge({
    required this.codeVerifier,
    required this.codeChallenge,
    required this.method,
    required this.createdAt,
  });

  /// Checks if the PKCE challenge has expired.
  /// Challenges are valid for 10 minutes to prevent replay attacks.
  bool get isExpired {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    return difference.inMinutes >= 10;
  }

  /// Creates a copy of this PKCEChallenge with updated fields.
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

  @override
  List<Object?> get props => [
        codeVerifier,
        codeChallenge,
        method,
        createdAt,
      ];

  @override
  String toString() => 'PKCEChallenge(method: $method, createdAt: $createdAt)';
}
