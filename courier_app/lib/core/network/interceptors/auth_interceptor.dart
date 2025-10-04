import 'package:dio/dio.dart';

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
/// - [High Priority] Remove debug print statements (use logging service)
/// - [Medium Priority] Add token expiry check before injection (prevent sending expired tokens)
/// - [Medium Priority] Support multiple auth schemes (Bearer, Basic, API Key)
/// - [Low Priority] Add metrics for auth header injection success/failure
/// - [Low Priority] Support conditional auth (some endpoints don't need auth)
class AuthInterceptor extends Interceptor {
  /// Function to retrieve current JWT access token
  ///
  /// **Why function instead of direct token:**
  /// - Token may change during app lifecycle (refresh, login, logout)
  /// - Ensures we always get the latest token
  /// - Avoids stale token issues
  ///
  /// **Returns:** Current JWT access token or null if not authenticated
  final String? Function() getAuthToken;

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
  /// - [getAuthToken]: Function to fetch current JWT token (required)
  /// - [getCsrfToken]: Function to fetch current CSRF token (required)
  ///
  /// **Example:**
  /// ```dart
  /// final interceptor = AuthInterceptor(
  ///   getAuthToken: () => secureStorage.read('access_token'),
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
  /// 1. Fetches current JWT access token via getAuthToken()
  /// 2. Adds Authorization header with Bearer scheme if token available
  /// 3. Checks if request is a write operation (POST/PUT/DELETE/PATCH)
  /// 4. Fetches CSRF token via getCsrfToken() for write operations
  /// 5. Adds X-CSRF-Token header if token available and method is write
  /// 6. Forwards request to next interceptor in chain
  ///
  /// **Token Injection Rules:**
  /// - **JWT Token**: Added to ALL requests (if available)
  /// - **CSRF Token**: Added ONLY to write operations (if available)
  ///
  /// **Flow:**
  /// ```
  /// onRequest
  ///    ↓
  /// Get JWT token → Add Authorization header (if token exists)
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
  /// - If CSRF token unavailable, write request continues (backend may reject)
  /// - Logs warnings in debug mode when tokens are missing
  ///
  /// **IMPROVEMENT:**
  /// - [High Priority] Remove print statements (use logging service)
  /// - [Medium Priority] Add retry logic when token is expired
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Debug logging
    print('=== AUTH INTERCEPTOR DEBUG ===');
    print('Request: ${options.method} ${options.path}');

    // Add Bearer token if available
    final authToken = getAuthToken();
    print('Auth token from getAuthToken(): ${authToken != null ? "YES (${authToken.substring(0, 20)}...)" : "NO"}');

    if (authToken != null && authToken.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $authToken';
      print('✅ Added Authorization header');
    } else {
      print('⚠️  No auth token - request will likely fail if protected');
    }

    // Add CSRF token for write operations (POST, PUT, DELETE, PATCH)
    final csrfToken = getCsrfToken();
    print('CSRF token available: ${csrfToken != null ? "YES" : "NO"}');
    print('Is write method: ${_isWriteMethod(options.method)}');

    if (csrfToken != null &&
        csrfToken.isNotEmpty &&
        _isWriteMethod(options.method)) {
      options.headers['X-CSRF-Token'] = csrfToken;
      print('✅ Added CSRF token header');
    } else if (_isWriteMethod(options.method)) {
      print('⚠️  No CSRF token for write operation - may fail');
    }

    print('Final headers: ${options.headers}');
    print('==============================');

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