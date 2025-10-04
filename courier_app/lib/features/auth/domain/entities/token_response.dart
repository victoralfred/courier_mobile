import 'package:equatable/equatable.dart';

/// [TokenResponse] - Domain entity representing OAuth2/JWT token response from authentication server
///
/// **What it does:**
/// - Encapsulates token response from OAuth2 token endpoint
/// - Parses standardized OAuth2 token response JSON
/// - Tracks access token, refresh token, and metadata
/// - Calculates token expiration timestamps
/// - Provides expiry detection and validation
/// - Supports OpenID Connect ID tokens
/// - Immutable entity with JSON serialization
///
/// **Why it exists:**
/// - Standardized OAuth2/JWT token representation
/// - Type-safe token response handling
/// - Automatic expiry tracking
/// - Clean separation from HTTP layer
/// - Supports multiple OAuth2 providers (standard format)
/// - Enables proactive token refresh logic
/// - Clean Architecture domain layer entity
///
/// **OAuth2 Token Response Format (RFC 6749):**
/// ```json
/// {
///   "access_token": "eyJhbGc...",
///   "token_type": "Bearer",
///   "expires_in": 3600,
///   "refresh_token": "refresh...",
///   "scope": "openid profile email",
///   "id_token": "eyJhbGc..." // OpenID Connect
/// }
/// ```
///
/// **Token Lifecycle:**
/// ```
/// [Token Exchange] ---> [TokenResponse Created]
///         |                      |
///         v                      v
/// [Store Tokens] <--- [Calculate expiresAt]
///         |
///         v
/// [Use Access Token] ---> Check: isExpired?
///         |                      |
///         |                      v (yes)
///         |              [Refresh Token]
///         |                      |
///         v (no)                 v
/// [Make API Call]    [New TokenResponse]
/// ```
///
/// **Usage Example:**
/// ```dart
/// // Parse from API response
/// final response = TokenResponse.fromJson({
///   'access_token': 'eyJhbGc...',
///   'token_type': 'Bearer',
///   'expires_in': 3600,
///   'refresh_token': 'refresh_token_here',
/// });
///
/// // Check expiry
/// if (response.isExpired) {
///   // Refresh token
///   final newResponse = await refreshToken(response.refreshToken!);
/// }
///
/// // Check if refresh needed soon
/// if (response.willExpireWithin(Duration(minutes: 5))) {
///   // Proactive refresh
/// }
///
/// // Convert back to JSON for storage
/// final json = response.toJson();
/// ```
///
/// **IMPROVEMENT:**
/// - [High Priority] Add token claims parsing from JWT
/// - [Medium Priority] Add token validation (signature, expiry from claims)
/// - [Medium Priority] Add scope parsing and validation
/// - [Low Priority] Add token type validation (must be Bearer)
/// - [Low Priority] Add automatic refresh mechanism
class TokenResponse extends Equatable {
  /// The access token (JWT) for API authentication
  ///
  /// **Format:** JWT token (base64url-encoded, three parts separated by dots)
  ///
  /// **Use cases:**
  /// - Authenticate API requests
  /// - Authorization header: "Bearer {accessToken}"
  /// - Short-lived (typically 15-60 minutes)
  ///
  /// **Security:** Treat as sensitive, don't log or expose
  final String accessToken;

  /// The refresh token for obtaining new access tokens
  ///
  /// **Optional:** Some flows don't provide refresh tokens
  ///
  /// **Characteristics:**
  /// - Long-lived (days to months)
  /// - Used to obtain new access tokens
  /// - Can be revoked by server
  /// - More sensitive than access token
  ///
  /// **Use cases:**
  /// - Refresh expired access tokens
  /// - Maintain persistent sessions
  /// - Offline access (if granted)
  ///
  /// **Security:** Encrypt in storage, never expose
  final String? refreshToken;

  /// The type of token (typically 'Bearer')
  ///
  /// **Default:** 'Bearer'
  ///
  /// **OAuth2 Standard:** "Bearer" for JWT tokens
  ///
  /// **Use cases:**
  /// - Authorization header format: "{tokenType} {accessToken}"
  /// - Compliance with OAuth2 spec
  final String tokenType;

  /// The expiration time in seconds from issuance
  ///
  /// **Optional:** May be null if not provided by server
  ///
  /// **Typical values:**
  /// - 900 (15 minutes)
  /// - 3600 (1 hour)
  /// - 86400 (24 hours)
  ///
  /// **Use cases:**
  /// - Calculate exact expiry timestamp
  /// - Schedule token refresh
  /// - Display session duration
  final int? expiresIn;

  /// The granted OAuth2 scopes
  ///
  /// **Optional:** May be null if not provided
  ///
  /// **Format:** Space-separated string (e.g., "openid profile email")
  ///
  /// **Use cases:**
  /// - Verify granted permissions
  /// - Compare with requested scopes
  /// - Enable/disable features based on scopes
  ///
  /// **Note:** May differ from requested scopes (user may deny some)
  final String? scope;

  /// The ID token for OpenID Connect flows
  ///
  /// **Optional:** Only provided in OpenID Connect flows
  ///
  /// **Format:** JWT containing user identity claims
  ///
  /// **Contains:**
  /// - User ID (sub)
  /// - Email
  /// - Name
  /// - Profile picture
  /// - Issuer, audience, expiry
  ///
  /// **Use cases:**
  /// - Extract user profile information
  /// - Verify user identity
  /// - SSO implementations
  final String? idToken;

  /// The timestamp when the token was received
  ///
  /// **Use cases:**
  /// - Calculate expiration time
  /// - Track token age
  /// - Analytics on token lifetime
  ///
  /// **Set automatically:** Current time when parsing JSON
  final DateTime receivedAt;

  /// Additional parameters from the token response
  ///
  /// **What it contains:**
  /// - Provider-specific parameters
  /// - Custom claims
  /// - Non-standard OAuth2 fields
  ///
  /// **Excludes:** Standard fields (access_token, refresh_token, etc.)
  ///
  /// **Use cases:**
  /// - Provider-specific features
  /// - Extended token metadata
  /// - Custom authentication flows
  final Map<String, dynamic> additionalParameters;

  /// Creates a TokenResponse with specified values
  ///
  /// **Parameters:**
  /// - [accessToken]: Access token JWT (required)
  /// - [refreshToken]: Refresh token (optional)
  /// - [tokenType]: Token type (default: 'Bearer')
  /// - [expiresIn]: Expiry duration in seconds (optional)
  /// - [scope]: Granted scopes (optional)
  /// - [idToken]: OpenID Connect ID token (optional)
  /// - [receivedAt]: Receive timestamp (required)
  /// - [additionalParameters]: Extra params (optional)
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

  /// Factory constructor to create from API response JSON
  ///
  /// **What it does:**
  /// - Parses standardized OAuth2 token response
  /// - Extracts standard fields (access_token, refresh_token, etc.)
  /// - Preserves additional/custom parameters
  /// - Sets receivedAt to current time
  ///
  /// **Parameters:**
  /// - [json]: Token response JSON from OAuth2 provider
  ///
  /// **Returns:** TokenResponse with parsed values
  ///
  /// **Required fields:**
  /// - access_token (throws if missing)
  ///
  /// **Optional fields:**
  /// - refresh_token, expires_in, scope, id_token
  ///
  /// **Example:**
  /// ```dart
  /// final json = await http.post(tokenEndpoint, ...);
  /// final response = TokenResponse.fromJson(jsonDecode(json.body));
  /// ```
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

  /// Calculates the expiration time of the access token
  ///
  /// **What it does:**
  /// - Adds expiresIn duration to receivedAt
  /// - Returns null if expiresIn not provided
  ///
  /// **Returns:** Exact expiration DateTime, or null
  ///
  /// **Example:**
  /// ```dart
  /// final expiry = response.expiresAt;
  /// if (expiry != null) {
  ///   print('Token expires at: $expiry');
  /// }
  /// ```
  DateTime? get expiresAt {
    if (expiresIn == null) return null;
    return receivedAt.add(Duration(seconds: expiresIn!));
  }

  /// Checks if the access token has expired
  ///
  /// **What it does:**
  /// - Compares current time with expiresAt
  /// - Returns false if expiresIn not provided
  ///
  /// **Returns:** true if token is expired
  ///
  /// **Use cases:**
  /// - Block usage of expired tokens
  /// - Trigger automatic refresh
  /// - Show "session expired" message
  ///
  /// **Example:**
  /// ```dart
  /// if (response.isExpired) {
  ///   await refreshAccessToken();
  /// }
  /// ```
  bool get isExpired {
    final expiry = expiresAt;
    if (expiry == null) return false;
    return DateTime.now().isAfter(expiry);
  }

  /// Checks if the token will expire within the given duration
  ///
  /// **What it does:**
  /// - Calculates future time (now + duration)
  /// - Checks if token expires before then
  /// - Returns false if expiresIn not provided
  ///
  /// **Parameters:**
  /// - [duration]: Time window to check
  ///
  /// **Returns:** true if token expires within duration
  ///
  /// **Use cases:**
  /// - Proactive token refresh
  /// - Warning before session expires
  /// - Schedule refresh operations
  ///
  /// **Example:**
  /// ```dart
  /// // Refresh if expiring within 5 minutes
  /// if (response.willExpireWithin(Duration(minutes: 5))) {
  ///   await proactiveRefresh();
  /// }
  /// ```
  bool willExpireWithin(Duration duration) {
    final expiry = expiresAt;
    if (expiry == null) return false;
    return DateTime.now().add(duration).isAfter(expiry);
  }

  /// Gets the remaining lifetime of the token
  ///
  /// **What it does:**
  /// - Calculates time until expiry
  /// - Returns Duration.zero if expired
  /// - Returns null if expiresIn not provided
  ///
  /// **Returns:** Remaining time, or null
  ///
  /// **Use cases:**
  /// - Display countdown to expiry
  /// - Calculate refresh timing
  /// - Analytics on token usage
  ///
  /// **Example:**
  /// ```dart
  /// final remaining = response.remainingLifetime;
  /// if (remaining != null && remaining.inMinutes < 5) {
  ///   showExpiryWarning('Session expires in ${remaining.inMinutes} minutes');
  /// }
  /// ```
  Duration? get remainingLifetime {
    final expiry = expiresAt;
    if (expiry == null) return null;
    final remaining = expiry.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Creates a copy with updated fields
  ///
  /// **What it does:**
  /// - Creates new TokenResponse with specified changes
  /// - Preserves unchanged fields
  /// - Maintains immutability
  ///
  /// **Parameters:** All optional, uses current value if not provided
  ///
  /// **Returns:** New TokenResponse instance with updates
  ///
  /// **Example:**
  /// ```dart
  /// // Update after refresh
  /// final refreshed = response.copyWith(
  ///   accessToken: newAccessToken,
  ///   receivedAt: DateTime.now(),
  /// );
  /// ```
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

  /// Converts the token response to JSON format
  ///
  /// **What it does:**
  /// - Serializes to standardized OAuth2 format
  /// - Includes additional parameters
  /// - Omits null optional fields
  ///
  /// **Returns:** JSON-serializable map
  ///
  /// **Use cases:**
  /// - Store in secure storage
  /// - Send to backend
  /// - Cache token response
  ///
  /// **Example:**
  /// ```dart
  /// final json = response.toJson();
  /// await secureStorage.write(key: 'token', value: jsonEncode(json));
  /// ```
  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        if (refreshToken != null) 'refresh_token': refreshToken,
        'token_type': tokenType,
        if (expiresIn != null) 'expires_in': expiresIn,
        if (scope != null) 'scope': scope,
        if (idToken != null) 'id_token': idToken,
        ...additionalParameters,
      };

  /// Equatable props - equality based on all fields
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

  /// String representation for debugging
  ///
  /// **Format:** TokenResponse(tokenType: ..., expiresIn: ..., hasRefreshToken: ...)
  ///
  /// **Security:** Doesn't include sensitive tokens
  @override
  String toString() =>
      'TokenResponse(tokenType: $tokenType, expiresIn: $expiresIn, hasRefreshToken: ${refreshToken != null})';
}
