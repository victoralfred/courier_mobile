import 'package:dio/dio.dart';
import 'package:delivery_app/core/services/app_logger.dart';
import 'package:delivery_app/features/auth/domain/entities/jwt_token.dart';

/// [AuthInterceptor] - Dio interceptor that automatically injects authentication and CSRF tokens into requests
///
/// **What it does:**
/// - Intercepts all outgoing HTTP requests before they're sent
/// - Adds JWT access token to Authorization header (Bearer scheme)
/// - Adds CSRF token to X-CSRF-Token header for write operations
/// - Provides debug logging for token injection (development mode)
/// - Handles cases where tokens are unavailable gracefully
///
/// **Why it exists:**
/// - Automates authentication token management (no manual header injection)
/// - Ensures consistent authentication across all API requests
/// - Separates authentication concerns from business logic
/// - Prevents forgetting to add auth headers in individual requests
/// - Centralizes token handling for easier maintenance
/// - Provides visibility into token injection through logging
///
/// **Token Injection Flow:**
/// ```
/// Request → AuthInterceptor
///             ↓
///         Get Auth Token (JWT)
///             ↓
///         Add Authorization: Bearer {token}
///             ↓
///         Is write method? (POST/PUT/DELETE/PATCH)
///             ↓ YES
///         Get CSRF Token
///             ↓
///         Add X-CSRF-Token: {csrf}
///             ↓
///         Forward request → Backend
/// ```
///
/// **Headers Added:**
/// - `Authorization: Bearer {jwt_token}` - For ALL requests (if token available)
/// - `X-CSRF-Token: {csrf_token}` - For write operations only (if token available)
///
/// **Usage Example:**
/// ```dart
/// // Create interceptor with token getters
/// final authInterceptor = AuthInterceptor(
///   getAuthToken: () => tokenManager.getAccessToken(),
///   getCsrfToken: () => csrfManager.getCurrentToken(),
/// );
///
/// // Add to Dio interceptor chain
/// final dio = Dio()
///   ..interceptors.add(authInterceptor);
///
/// // Now all requests get auth headers automatically
/// await dio.get('/users/profile'); // ← Authorization header added automatically
/// await dio.post('/orders', data: order); // ← Both Authorization and CSRF headers added
/// ```
///
/// **IMPROVEMENT:**
/// - [Medium Priority] Support multiple auth schemes (Bearer, Basic, API Key)
/// - [Low Priority] Add metrics for auth header injection success/failure
/// - [Low Priority] Support conditional auth (some endpoints don't need auth)
class AuthInterceptor extends Interceptor {
  /// Logger instance for auth interceptor operations
  static final _logger = AppLogger.auth();

  /// Function to retrieve current JWT token object
  ///
  /// **Why function instead of direct token:**
  /// - Token may change during app lifecycle (refresh, login, logout)
  /// - Ensures we always get the latest token
  /// - Avoids stale token issues
  /// - Provides access to expiry metadata for validation
  ///
  /// **Returns:** Current JwtToken object or null if not authenticated
  final JwtToken? Function() getAuthToken;

  /// Function to retrieve current CSRF token for write operations
  ///
  /// **Why needed:**
  /// - CSRF tokens protect against Cross-Site Request Forgery attacks
  /// - Required for all state-changing operations (POST, PUT, DELETE, PATCH)
  /// - Token may be ephemeral (changes per request)
  ///
  /// **Returns:** Current CSRF token or null if not available
  final String? Function() getCsrfToken;

  /// Creates authentication interceptor
  ///
  /// **Parameters:**
  /// - [getAuthToken]: Function to fetch current JwtToken object (required)
  /// - [getCsrfToken]: Function to fetch current CSRF token (required)
  ///
  /// **Example:**
  /// ```dart
  /// final interceptor = AuthInterceptor(
  ///   getAuthToken: () async {
  ///     final result = await tokenManager.getToken();
  ///     return result;
  ///   },
  ///   getCsrfToken: () => csrfManager.getToken(),
  /// );
  /// ```
  AuthInterceptor({
    required this.getAuthToken,
    required this.getCsrfToken,
  });

  /// Intercepts request and injects authentication and CSRF tokens
  ///
  /// **What it does:**
  /// 1. Fetches current JWT token object via getAuthToken()
  /// 2. Checks token expiry and logs warnings if expired or should refresh
  /// 3. Adds Authorization header with Bearer scheme if token available
  /// 4. Checks if request is a write operation (POST/PUT/DELETE/PATCH)
  /// 5. Fetches CSRF token via getCsrfToken() for write operations
  /// 6. Adds X-CSRF-Token header if token available and method is write
  /// 7. Forwards request to next interceptor in chain
  ///
  /// **Token Injection Rules:**
  /// - **JWT Token**: Added to ALL requests (if available and not null)
  /// - **CSRF Token**: Added ONLY to write operations (if available)
  ///
  /// **Token Expiry Handling:**
  /// - Checks token.isExpired before injection
  /// - Checks token.shouldRefresh (5 min before expiry)
  /// - Logs warnings for expired/expiring tokens
  /// - Still injects expired tokens (backend will reject with 401)
  ///
  /// **Flow:**
  /// ```
  /// onRequest
  ///    ↓
  /// Get JWT token object
  ///    ↓
  /// Check expiry → Log warning if expired/should refresh
  ///    ↓
  /// Add Authorization header (if token exists)
  ///    ↓
  /// Is write method? → NO → Forward request
  ///    ↓ YES
  /// Get CSRF token → Add X-CSRF-Token header (if token exists)
  ///    ↓
  /// Forward request
  /// ```
  ///
  /// **Parameters:**
  /// - [options]: Request options (method, path, headers, etc.)
  /// - [handler]: Handler to forward request to next interceptor
  ///
  /// **Graceful Degradation:**
  /// - If auth token unavailable, request continues without Authorization header
  /// - If token expired, still adds to header (logs warning, backend will reject)
  /// - If CSRF token unavailable, write request continues (backend may reject)
  /// - Logs warnings in debug mode when tokens are missing/expired
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _logger.debug('Auth: Processing request', metadata: {
      'method': options.method,
      'path': options.path,
    });

    // Get JWT token object
    final jwtToken = getAuthToken();

    if (jwtToken != null) {
      // Check token expiry status
      if (jwtToken.isExpired) {
        _logger.warning('JWT token is expired', metadata: {
          'expiresAt': jwtToken.expiresAt.toIso8601String(),
          'expiredAgo': DateTime.now().difference(jwtToken.expiresAt).inMinutes,
        });
      } else if (jwtToken.shouldRefresh) {
        _logger.warning('JWT token should be refreshed soon', metadata: {
          'expiresAt': jwtToken.expiresAt.toIso8601String(),
          'expiresIn': jwtToken.remainingLifetime.inMinutes,
        });
      }

      // Add Authorization header with full token string
      options.headers['Authorization'] = '${jwtToken.type} ${jwtToken.token}';
      _logger.info('Authorization header added', metadata: {
        'tokenType': jwtToken.type,
        'isExpired': jwtToken.isExpired,
        'shouldRefresh': jwtToken.shouldRefresh,
      });
    } else {
      _logger.warning('No auth token - request will likely fail if protected');
    }

    // Add CSRF token for write operations (POST, PUT, DELETE, PATCH)
    final csrfToken = getCsrfToken();
    final hasCsrfToken = csrfToken != null && csrfToken.isNotEmpty;
    final isWriteOp = _isWriteMethod(options.method);

    if (hasCsrfToken && isWriteOp) {
      options.headers['X-CSRF-Token'] = csrfToken;
      _logger.info('CSRF token header added');
    } else if (isWriteOp) {
      _logger.warning('No CSRF token for write operation - may fail');
    }

    handler.next(options);
  }

  /// Checks if HTTP method is a write operation requiring CSRF protection
  ///
  /// **What it does:**
  /// - Returns true for state-changing operations (POST, PUT, DELETE, PATCH)
  /// - Returns false for read operations (GET, HEAD, OPTIONS)
  ///
  /// **Why:**
  /// - CSRF attacks only affect state-changing operations
  /// - Read operations don't need CSRF protection (no server-side changes)
  /// - Follows OWASP CSRF prevention recommendations
  ///
  /// **Parameters:**
  /// - [method]: HTTP method name (case-insensitive)
  ///
  /// **Returns:** true if method requires CSRF protection, false otherwise
  ///
  /// **Example:**
  /// ```dart
  /// _isWriteMethod('POST')   // → true
  /// _isWriteMethod('PUT')    // → true
  /// _isWriteMethod('DELETE') // → true
  /// _isWriteMethod('PATCH')  // → true
  /// _isWriteMethod('GET')    // → false
  /// _isWriteMethod('HEAD')   // → false
  /// ```
  bool _isWriteMethod(String method) {
    final upperMethod = method.toUpperCase();
    return upperMethod == 'POST' ||
        upperMethod == 'PUT' ||
        upperMethod == 'DELETE' ||
        upperMethod == 'PATCH';
  }
}