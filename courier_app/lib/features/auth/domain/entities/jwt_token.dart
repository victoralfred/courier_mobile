import 'package:equatable/equatable.dart';

/// Represents a JWT token with metadata
class JwtToken extends Equatable {
  /// The encoded JWT token string
  final String token;

  /// Token type (typically "Bearer")
  final String type;

  /// When the token was issued
  final DateTime issuedAt;

  /// When the token expires
  final DateTime expiresAt;

  /// Optional refresh token
  final String? refreshToken;

  /// CSRF token for write operations
  final String? csrfToken;

  const JwtToken({
    required this.token,
    required this.type,
    required this.issuedAt,
    required this.expiresAt,
    this.refreshToken,
    this.csrfToken,
  });

  /// Check if the token is expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Check if the token should be refreshed (5 minutes before expiry)
  bool get shouldRefresh {
    final now = DateTime.now();
    final refreshThreshold = expiresAt.subtract(const Duration(minutes: 5));
    return now.isAfter(refreshThreshold);
  }

  /// Get the remaining lifetime of the token
  Duration get remainingLifetime {
    final now = DateTime.now();
    if (isExpired) return Duration.zero;
    return expiresAt.difference(now);
  }

  /// Format the authorization header value
  String get authorizationHeader => '$type $token';

  /// Create a copy with updated values
  JwtToken copyWith({
    String? token,
    String? type,
    DateTime? issuedAt,
    DateTime? expiresAt,
    String? refreshToken,
    String? csrfToken,
  }) =>
      JwtToken(
        token: token ?? this.token,
        type: type ?? this.type,
        issuedAt: issuedAt ?? this.issuedAt,
        expiresAt: expiresAt ?? this.expiresAt,
        refreshToken: refreshToken ?? this.refreshToken,
        csrfToken: csrfToken ?? this.csrfToken,
      );

  @override
  List<Object?> get props => [
        token,
        type,
        issuedAt,
        expiresAt,
        refreshToken,
        csrfToken,
      ];
}
