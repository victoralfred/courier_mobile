import 'package:equatable/equatable.dart';

/// [JwtToken] - Domain entity representing a JWT authentication token with metadata
///
/// **What it does:**
/// - Encapsulates JWT access token and optional refresh token
/// - Tracks token lifecycle (issuance, expiration)
/// - Provides automatic expiry detection
/// - Supports proactive token refresh logic
/// - Includes CSRF token for write operation security
/// - Formats authorization headers
/// - Immutable entity with copyWith pattern
///
/// **Why it exists:**
/// - Centralized token management
/// - Type-safe token handling
/// - Automatic expiry tracking prevents auth failures
/// - Proactive refresh improves UX (no mid-request expiry)
/// - CSRF protection for state-changing operations
/// - Clean Architecture domain layer entity
/// - Separates token logic from infrastructure
///
/// **Token Lifecycle:**
/// 1. Token issued with expiresAt timestamp
/// 2. shouldRefresh triggers 5 minutes before expiry
/// 3. Token refresh prevents expiry
/// 4. isExpired blocks usage of stale tokens
///
/// **Usage Example:**
/// ```dart
/// // Create token from auth response
/// final token = JwtToken(
///   token: 'eyJhbGciOiJIUzI1NiIs...',
///   type: 'Bearer',
///   issuedAt: DateTime.now(),
///   expiresAt: DateTime.now().add(Duration(hours: 1)),
///   refreshToken: 'refresh_token_here',
///   csrfToken: 'csrf_token_here',
/// );
///
/// // Add to API request
/// final headers = {
///   'Authorization': token.authorizationHeader,
///   'X-CSRF-Token': token.csrfToken,
/// };
///
/// // Check if refresh needed
/// if (token.shouldRefresh) {
///   await refreshAuthToken(token.refreshToken);
/// }
///
/// // Validate before use
/// if (!token.isExpired) {
///   await makeApiCall(token);
/// }
/// ```
///
/// **Security Flow:**
/// ```
/// [Client] ---(login)---> [Auth Server]
///                              |
///                              v
///                        [JWT + Refresh]
///                              |
///                              v
///      [Store tokens] <--------+
///            |
///            v
///      [API Request]
///            |
///            +---> Check: isExpired?
///            |         |
///            |         v (yes)
///            |    [Refresh token]
///            |
///            v (no)
///      [Add auth header]
///            |
///            v
///      [Make request]
/// ```
///
/// **IMPROVEMENT:**
/// - [High Priority] Add token claims parsing (userId, roles, permissions)
/// - [High Priority] Add token signature validation
/// - [Medium Priority] Add configurable refresh threshold (currently hardcoded 5 min)
/// - [Medium Priority] Add token revocation/blacklist checking
/// - [Low Priority] Add token scope/audience validation
/// - [Low Priority] Add automatic refresh mechanism via callback
class JwtToken extends Equatable {
  /// The encoded JWT token string
  ///
  /// **Format:** Three base64url-encoded parts separated by dots
  /// - Header: Algorithm and token type
  /// - Payload: Claims (user data, expiry, etc.)
  /// - Signature: Cryptographic signature
  ///
  /// **Example:** eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0...
  ///
  /// **Security:** Treat as sensitive data, don't log or expose
  final String token;

  /// Token type (typically "Bearer")
  ///
  /// **Default:** "Bearer"
  ///
  /// **Use cases:**
  /// - Authorization header format: "{type} {token}"
  /// - OAuth 2.0 standard compliance
  final String type;

  /// When the token was issued
  ///
  /// **Use cases:**
  /// - Token age tracking
  /// - Audit logging
  /// - Analytics on token usage patterns
  final DateTime issuedAt;

  /// When the token expires
  ///
  /// **Use cases:**
  /// - Automatic expiry detection
  /// - Proactive refresh timing
  /// - Security (prevents long-lived tokens)
  ///
  /// **Typical lifetime:** 15 minutes to 1 hour
  final DateTime expiresAt;

  /// Optional refresh token for obtaining new access tokens
  ///
  /// **Optional:** May be null for short-lived sessions
  ///
  /// **Characteristics:**
  /// - Longer lifetime than access token
  /// - Used to obtain new access tokens
  /// - Can be revoked by server
  /// - Single-use or reusable depending on implementation
  ///
  /// **Security:** More sensitive than access token, encrypt in storage
  final String? refreshToken;

  /// CSRF token for write operations
  ///
  /// **Optional:** May be null if CSRF protection not implemented
  ///
  /// **Use cases:**
  /// - Prevent Cross-Site Request Forgery attacks
  /// - Required for POST/PUT/DELETE operations
  /// - Included in request headers or form data
  ///
  /// **Implementation:** Often ephemeral, regenerated per session
  final String? csrfToken;

  /// Creates a JwtToken with specified values
  ///
  /// **Parameters:**
  /// - [token]: JWT token string (required)
  /// - [type]: Token type (required, typically "Bearer")
  /// - [issuedAt]: Issuance timestamp (required)
  /// - [expiresAt]: Expiration timestamp (required)
  /// - [refreshToken]: Refresh token (optional)
  /// - [csrfToken]: CSRF protection token (optional)
  ///
  /// **Validation:** No validation performed, assumes valid input
  const JwtToken({
    required this.token,
    required this.type,
    required this.issuedAt,
    required this.expiresAt,
    this.refreshToken,
    this.csrfToken,
  });

  /// Check if the token is expired
  ///
  /// **What it does:**
  /// - Compares current time with expiresAt
  /// - Returns true if current time is after expiry
  ///
  /// **Returns:** true if token is expired
  ///
  /// **Use cases:**
  /// - Block API requests with expired tokens
  /// - Trigger re-authentication
  /// - Show session expired UI
  ///
  /// **Example:**
  /// ```dart
  /// if (token.isExpired) {
  ///   // Redirect to login
  ///   await logout();
  /// }
  /// ```
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Check if the token should be refreshed (5 minutes before expiry)
  ///
  /// **What it does:**
  /// - Calculates refresh threshold (expiry - 5 minutes)
  /// - Returns true if current time past threshold
  ///
  /// **Why 5 minutes:**
  /// - Prevents mid-request expiry
  /// - Allows time for refresh operation
  /// - Balances UX and security
  ///
  /// **Returns:** true if token should be proactively refreshed
  ///
  /// **Use cases:**
  /// - Proactive token refresh (invisible to user)
  /// - Prevent auth errors during user activity
  /// - Maintain seamless user experience
  ///
  /// **Example:**
  /// ```dart
  /// // Before API call
  /// if (token.shouldRefresh && token.refreshToken != null) {
  ///   final newToken = await authService.refreshToken(token.refreshToken!);
  ///   // Use new token for request
  /// }
  /// ```
  bool get shouldRefresh {
    final now = DateTime.now();
    final refreshThreshold = expiresAt.subtract(const Duration(minutes: 5));
    return now.isAfter(refreshThreshold);
  }

  /// Get the remaining lifetime of the token
  ///
  /// **What it does:**
  /// - Calculates time until expiry
  /// - Returns Duration.zero if expired
  ///
  /// **Returns:** Remaining time until expiry
  ///
  /// **Use cases:**
  /// - Display "session expires in X minutes"
  /// - Schedule automatic refresh
  /// - Determine if worth refreshing vs re-login
  ///
  /// **Example:**
  /// ```dart
  /// final remaining = token.remainingLifetime;
  /// if (remaining.inMinutes < 10) {
  ///   showWarning('Session expiring soon: ${remaining.inMinutes} minutes');
  /// }
  /// ```
  Duration get remainingLifetime {
    final now = DateTime.now();
    if (isExpired) return Duration.zero;
    return expiresAt.difference(now);
  }

  /// Format the authorization header value
  ///
  /// **What it does:**
  /// - Combines type and token with space
  /// - Returns standard OAuth 2.0 format
  ///
  /// **Returns:** "{type} {token}" (e.g., "Bearer eyJhbG...")
  ///
  /// **Use cases:**
  /// - HTTP Authorization header
  /// - API request authentication
  ///
  /// **Example:**
  /// ```dart
  /// final headers = {
  ///   'Authorization': token.authorizationHeader,
  /// };
  /// await http.get(url, headers: headers);
  /// ```
  String get authorizationHeader => '$type $token';

  /// Create a copy with updated values
  ///
  /// **What it does:**
  /// - Creates new JwtToken with specified changes
  /// - Preserves unchanged fields
  /// - Maintains immutability
  ///
  /// **Parameters:** All optional, uses current value if not provided
  ///
  /// **Returns:** New JwtToken instance with updates
  ///
  /// **Example:**
  /// ```dart
  /// // Update after refresh
  /// final refreshed = token.copyWith(
  ///   token: newAccessToken,
  ///   issuedAt: DateTime.now(),
  ///   expiresAt: DateTime.now().add(Duration(hours: 1)),
  /// );
  ///
  /// // Update CSRF token
  /// final withCsrf = token.copyWith(csrfToken: newCsrfToken);
  /// ```
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

  /// Equatable props - equality based on all fields
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
