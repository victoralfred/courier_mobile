import 'package:equatable/equatable.dart';
import 'oauth_provider.dart';
import 'pkce_challenge.dart';

/// [AuthorizationRequest] - Domain entity representing an OAuth2 authorization request with PKCE
///
/// **What it does:**
/// - Encapsulates OAuth2 authorization flow state
/// - Tracks PKCE challenge for secure token exchange
/// - Stores CSRF protection state parameter
/// - Manages request lifecycle (creation, expiry, usage)
/// - Prevents replay attacks via isUsed flag
/// - Supports OpenID Connect nonce parameter
/// - Immutable entity with copyWith pattern
///
/// **Why it exists:**
/// - Centralized OAuth2 request state management
/// - Security: Prevents CSRF and replay attacks
/// - Enables proper PKCE flow implementation
/// - Associates authorization callback with original request
/// - Clean separation of request and response
/// - Validates request before token exchange
/// - Audit trail for authorization attempts
///
/// **Request Lifecycle:**
/// 1. Create request with PKCE challenge and state
/// 2. Build authorization URL
/// 3. User redirected to provider
/// 4. Provider redirects back with code and state
/// 5. Validate state matches (CSRF protection)
/// 6. Validate not expired and not used
/// 7. Exchange code for token using PKCE verifier
/// 8. Mark request as used
///
/// **Security Flow:**
/// ```
/// [Create Request] --> [Generate PKCE + State]
///        |                       |
///        v                       v
/// [Build URL] <------ [Store Request]
///        |
///        v
/// [User Authorizes] ---> [Callback with code + state]
///        |
///        v
/// [Validate State] ---> Match? ---> [Exchange Code]
///        |                               |
///        |                               v
///        |                      [Verify PKCE]
///        |                               |
///        v (fail)                        v
/// [Reject: CSRF]              [Mark as Used]
/// ```
///
/// **Usage Example:**
/// ```dart
/// // Create authorization request
/// final request = AuthorizationRequest(
///   id: uuid.v4(),
///   provider: OAuthProvider.google(...),
///   pkceChallenge: PKCEChallenge.generate(),
///   state: generateRandomString(32),
///   authorizationUrl: provider.buildAuthorizationUrl(...),
///   createdAt: DateTime.now(),
/// );
///
/// // Open authorization URL
/// await launchUrl(Uri.parse(request.authorizationUrl));
///
/// // On callback, validate request
/// if (request.isValid && callbackState == request.state) {
///   // Exchange code for token
///   final token = await exchangeCode(
///     code: authorizationCode,
///     verifier: request.pkceChallenge.codeVerifier,
///   );
///
///   // Mark as used
///   await saveRequest(request.markAsUsed());
/// }
/// ```
///
/// **IMPROVEMENT:**
/// - [High Priority] Add configurable expiry duration (currently hardcoded 10 min)
/// - [Medium Priority] Add request origin tracking (deep link vs web)
/// - [Medium Priority] Add error handling for failed authorizations
/// - [Low Priority] Add analytics tracking (success rate, timing)
/// - [Low Priority] Add automatic cleanup of expired requests
class AuthorizationRequest extends Equatable {
  /// Unique identifier for this authorization request
  ///
  /// **Format:** UUID v4
  ///
  /// **Use cases:**
  /// - Track request in storage
  /// - Associate callback with original request
  /// - Audit logging
  final String id;

  /// The OAuth provider being used
  ///
  /// **Contains:**
  /// - Provider type (Google, GitHub, etc.)
  /// - OAuth endpoints
  /// - Client credentials
  /// - Scopes
  final OAuthProvider provider;

  /// The PKCE challenge associated with this request
  ///
  /// **Contains:**
  /// - Code verifier (kept secret)
  /// - Code challenge (sent to provider)
  /// - Challenge method (S256)
  ///
  /// **Security:** Verifier used later for token exchange
  final PKCEChallenge pkceChallenge;

  /// The state parameter for CSRF protection
  ///
  /// **What it is:**
  /// - Random string generated for this request
  /// - Sent to provider in authorization URL
  /// - Provider returns it in callback
  /// - Must match to prevent CSRF attacks
  ///
  /// **Format:** Cryptographically random string (32+ characters)
  ///
  /// **Security:** Critical for CSRF protection
  final String state;

  /// The authorization URL to redirect the user to
  ///
  /// **What it contains:**
  /// - Provider authorization endpoint
  /// - Client ID
  /// - Redirect URI
  /// - Scopes
  /// - State parameter
  /// - PKCE code challenge
  ///
  /// **Use cases:**
  /// - Open in browser/webview
  /// - Deep link handling
  final String authorizationUrl;

  /// The timestamp when this request was created
  ///
  /// **Use cases:**
  /// - Expiry validation
  /// - Request age tracking
  /// - Analytics on authorization flow duration
  final DateTime createdAt;

  /// Optional nonce for additional security (OpenID Connect)
  ///
  /// **Optional:** Used with OpenID Connect providers
  ///
  /// **What it is:**
  /// - Random value included in ID token
  /// - Prevents token replay attacks
  /// - Binds token to this request
  ///
  /// **Use cases:**
  /// - OpenID Connect flows
  /// - ID token validation
  final String? nonce;

  /// Whether this request has been used (prevents replay attacks)
  ///
  /// **Default:** false
  ///
  /// **Use cases:**
  /// - Prevent authorization code reuse
  /// - Single-use request enforcement
  /// - Security audit trail
  ///
  /// **Security:** Once used, request cannot be reused
  final bool isUsed;

  /// Creates an AuthorizationRequest with specified values
  ///
  /// **Parameters:**
  /// - [id]: Unique request identifier (required, should be UUID)
  /// - [provider]: OAuth provider config (required)
  /// - [pkceChallenge]: PKCE challenge (required)
  /// - [state]: CSRF protection token (required, cryptographically random)
  /// - [authorizationUrl]: Full authorization URL (required)
  /// - [createdAt]: Creation timestamp (required)
  /// - [nonce]: OpenID Connect nonce (optional)
  /// - [isUsed]: Usage flag (default: false)
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

  /// Checks if the authorization request has expired
  ///
  /// **What it does:**
  /// - Calculates age of request
  /// - Compares against 10 minute threshold
  ///
  /// **Why 10 minutes:**
  /// - Balances security and UX
  /// - Typical authorization flow duration: 1-5 minutes
  /// - Prevents stale request usage
  ///
  /// **Returns:** true if request is older than 10 minutes
  ///
  /// **Use cases:**
  /// - Validate request before token exchange
  /// - Cleanup expired requests
  /// - Show "request expired" error
  ///
  /// **Example:**
  /// ```dart
  /// if (request.isExpired) {
  ///   throw AuthorizationExpiredError();
  /// }
  /// ```
  bool get isExpired {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    return difference.inMinutes > 10;
  }

  /// Validates if this request is still valid
  ///
  /// **What it checks:**
  /// - Request not expired
  /// - Request not already used
  /// - PKCE challenge not expired
  ///
  /// **Returns:** true if all validations pass
  ///
  /// **Use cases:**
  /// - Pre-token-exchange validation
  /// - Authorization callback validation
  /// - Security checks
  ///
  /// **Example:**
  /// ```dart
  /// if (!request.isValid) {
  ///   throw InvalidAuthorizationRequestError();
  /// }
  /// ```
  bool get isValid => !isExpired && !isUsed && !pkceChallenge.isExpired;

  /// Creates a copy with updated fields
  ///
  /// **What it does:**
  /// - Creates new AuthorizationRequest with specified changes
  /// - Preserves unchanged fields
  /// - Maintains immutability
  ///
  /// **Parameters:** All optional, uses current value if not provided
  ///
  /// **Returns:** New AuthorizationRequest instance with updates
  ///
  /// **Example:**
  /// ```dart
  /// // Mark as used
  /// final used = request.copyWith(isUsed: true);
  ///
  /// // Update provider config
  /// final updated = request.copyWith(provider: newProvider);
  /// ```
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

  /// Marks this request as used
  ///
  /// **What it does:**
  /// - Creates new request with isUsed = true
  /// - Prevents request reuse
  ///
  /// **Returns:** New AuthorizationRequest marked as used
  ///
  /// **Use cases:**
  /// - After successful token exchange
  /// - Prevent replay attacks
  /// - Audit trail
  ///
  /// **Example:**
  /// ```dart
  /// final token = await exchangeCode(request);
  /// await storage.save(request.markAsUsed());
  /// ```
  AuthorizationRequest markAsUsed() => copyWith(isUsed: true);

  /// Equatable props - equality based on all fields
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

  /// String representation for debugging
  ///
  /// **Format:** AuthorizationRequest(id: ..., provider: ..., createdAt: ..., isUsed: ...)
  @override
  String toString() =>
      'AuthorizationRequest(id: $id, provider: ${provider.displayName}, createdAt: $createdAt, isUsed: $isUsed)';
}