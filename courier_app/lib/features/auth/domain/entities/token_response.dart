import 'package:equatable/equatable.dart';

/// Represents an OAuth2/JWT token response from the authentication server.
class TokenResponse extends Equatable {
  /// The access token (JWT) for API authentication.
  final String accessToken;

  /// The refresh token for obtaining new access tokens.
  final String? refreshToken;

  /// The type of token (typically 'Bearer').
  final String tokenType;

  /// The expiration time in seconds from issuance.
  final int? expiresIn;

  /// The granted OAuth2 scopes.
  final String? scope;

  /// The ID token for OpenID Connect flows.
  final String? idToken;

  /// The timestamp when the token was received.
  final DateTime receivedAt;

  /// Additional parameters from the token response.
  final Map<String, dynamic> additionalParameters;

  const TokenResponse({
    required this.accessToken,
    this.refreshToken,
    this.tokenType = 'Bearer',
    this.expiresIn,
    this.scope,
    this.idToken,
    required this.receivedAt,
    this.additionalParameters = const {},
  });

  /// Factory constructor to create from API response JSON.
  factory TokenResponse.fromJson(Map<String, dynamic> json) => TokenResponse(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String?,
        tokenType: json['token_type'] as String? ?? 'Bearer',
        expiresIn: json['expires_in'] as int?,
        scope: json['scope'] as String?,
        idToken: json['id_token'] as String?,
        receivedAt: DateTime.now(),
        additionalParameters: Map<String, dynamic>.from(json)
          ..removeWhere((key, _) => [
                'access_token',
                'refresh_token',
                'token_type',
                'expires_in',
                'scope',
                'id_token'
              ].contains(key)),
      );

  /// Calculates the expiration time of the access token.
  DateTime? get expiresAt {
    if (expiresIn == null) return null;
    return receivedAt.add(Duration(seconds: expiresIn!));
  }

  /// Checks if the access token has expired.
  bool get isExpired {
    final expiry = expiresAt;
    if (expiry == null) return false;
    return DateTime.now().isAfter(expiry);
  }

  /// Checks if the token will expire within the given duration.
  bool willExpireWithin(Duration duration) {
    final expiry = expiresAt;
    if (expiry == null) return false;
    return DateTime.now().add(duration).isAfter(expiry);
  }

  /// Gets the remaining lifetime of the token.
  Duration? get remainingLifetime {
    final expiry = expiresAt;
    if (expiry == null) return null;
    final remaining = expiry.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Creates a copy with updated fields.
  TokenResponse copyWith({
    String? accessToken,
    String? refreshToken,
    String? tokenType,
    int? expiresIn,
    String? scope,
    String? idToken,
    DateTime? receivedAt,
    Map<String, dynamic>? additionalParameters,
  }) =>
      TokenResponse(
        accessToken: accessToken ?? this.accessToken,
        refreshToken: refreshToken ?? this.refreshToken,
        tokenType: tokenType ?? this.tokenType,
        expiresIn: expiresIn ?? this.expiresIn,
        scope: scope ?? this.scope,
        idToken: idToken ?? this.idToken,
        receivedAt: receivedAt ?? this.receivedAt,
        additionalParameters: additionalParameters ?? this.additionalParameters,
      );

  /// Converts the token response to JSON format.
  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        if (refreshToken != null) 'refresh_token': refreshToken,
        'token_type': tokenType,
        if (expiresIn != null) 'expires_in': expiresIn,
        if (scope != null) 'scope': scope,
        if (idToken != null) 'id_token': idToken,
        ...additionalParameters,
      };

  @override
  List<Object?> get props => [
        accessToken,
        refreshToken,
        tokenType,
        expiresIn,
        scope,
        idToken,
        receivedAt,
        additionalParameters,
      ];

  @override
  String toString() =>
      'TokenResponse(tokenType: $tokenType, expiresIn: $expiresIn, hasRefreshToken: ${refreshToken != null})';
}
