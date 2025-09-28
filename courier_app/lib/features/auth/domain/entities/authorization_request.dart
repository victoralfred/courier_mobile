import 'package:equatable/equatable.dart';
import 'oauth_provider.dart';
import 'pkce_challenge.dart';

/// Represents an OAuth2 authorization request with PKCE.
class AuthorizationRequest extends Equatable {
  /// Unique identifier for this authorization request.
  final String id;

  /// The OAuth provider being used.
  final OAuthProvider provider;

  /// The PKCE challenge associated with this request.
  final PKCEChallenge pkceChallenge;

  /// The state parameter for CSRF protection.
  final String state;

  /// The authorization URL to redirect the user to.
  final String authorizationUrl;

  /// The timestamp when this request was created.
  final DateTime createdAt;

  /// Optional nonce for additional security (OpenID Connect).
  final String? nonce;

  /// Whether this request has been used (prevents replay attacks).
  final bool isUsed;

  const AuthorizationRequest({
    required this.id,
    required this.provider,
    required this.pkceChallenge,
    required this.state,
    required this.authorizationUrl,
    required this.createdAt,
    this.nonce,
    this.isUsed = false,
  });

  /// Checks if the authorization request has expired.
  /// Requests are valid for 10 minutes.
  bool get isExpired {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    return difference.inMinutes > 10;
  }

  /// Validates if this request is still valid.
  bool get isValid => !isExpired && !isUsed && !pkceChallenge.isExpired;

  /// Creates a copy with updated fields.
  AuthorizationRequest copyWith({
    String? id,
    OAuthProvider? provider,
    PKCEChallenge? pkceChallenge,
    String? state,
    String? authorizationUrl,
    DateTime? createdAt,
    String? nonce,
    bool? isUsed,
  }) =>
      AuthorizationRequest(
        id: id ?? this.id,
        provider: provider ?? this.provider,
        pkceChallenge: pkceChallenge ?? this.pkceChallenge,
        state: state ?? this.state,
        authorizationUrl: authorizationUrl ?? this.authorizationUrl,
        createdAt: createdAt ?? this.createdAt,
        nonce: nonce ?? this.nonce,
        isUsed: isUsed ?? this.isUsed,
      );

  /// Marks this request as used.
  AuthorizationRequest markAsUsed() => copyWith(isUsed: true);

  @override
  List<Object?> get props => [
        id,
        provider,
        pkceChallenge,
        state,
        authorizationUrl,
        createdAt,
        nonce,
        isUsed,
      ];

  @override
  String toString() =>
      'AuthorizationRequest(id: $id, provider: ${provider.displayName}, createdAt: $createdAt, isUsed: $isUsed)';
}