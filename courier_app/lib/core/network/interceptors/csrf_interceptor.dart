import 'package:dio/dio.dart';
import 'package:delivery_app/core/network/csrf_token_manager.dart';
import 'package:delivery_app/core/services/app_logger.dart';

/// [CsrfInterceptor] - Dio interceptor that automatically injects CSRF tokens into write requests
///
/// **What it does:**
/// - Intercepts outgoing HTTP requests before they're sent
/// - Fetches fresh CSRF token from CsrfTokenManager for write operations
/// - Adds token to request headers as 'X-CSRF-Token'
/// - Skips CSRF for read operations (GET, HEAD, OPTIONS)
/// - Excludes specific paths from CSRF protection (auth endpoints)
/// - Gracefully handles CSRF token fetch failures
///
/// **Why it exists:**
/// - CSRF (Cross-Site Request Forgery) protection for state-changing operations
/// - Prevents unauthorized actions from malicious websites
/// - Automates CSRF token management (no manual header injection needed)
/// - Follows OWASP security best practices
/// - Separates security concerns from business logic
///
/// **Security Flow:**
/// ```
/// Request → CsrfInterceptor → Check if write method
///                             ↓
///                         Fetch CSRF token
///                             ↓
///                     Add X-CSRF-Token header
///                             ↓
///                    Forward request → Backend
/// ```
///
/// **Write Methods Protected:**
/// - POST (create resources)
/// - PUT (update resources)
/// - DELETE (remove resources)
/// - PATCH (partial updates)
///
/// **Read Methods Skipped:**
/// - GET (read resources)
/// - HEAD (headers only)
/// - OPTIONS (CORS preflight)
///
/// **Usage Example:**
/// ```dart
/// // Add to Dio interceptor chain
/// final dio = Dio()
///   ..interceptors.add(
///     CsrfInterceptor(
///       csrfTokenManager: csrfManager,
///       excludedPaths: ['/users/auth', '/auth/csrf'],
///       useNullableGetter: true, // Don't throw on token fetch failure
///     ),
///   );
///
/// // Now all POST/PUT/DELETE/PATCH requests get CSRF tokens automatically
/// await dio.post('/orders', data: orderData); // ← CSRF added automatically
/// ```
///
/// **IMPROVEMENT:**
/// - [Medium Priority] Add configurable retry on CSRF fetch failure
/// - [Medium Priority] Cache CSRF token for 5-10 minutes (reduce API calls)
/// - [Low Priority] Add metrics for CSRF success/failure rates
/// - [Low Priority] Support custom header name (currently hardcoded to X-CSRF-Token)
class CsrfInterceptor extends Interceptor {
  /// CSRF token manager that fetches tokens from backend
  final CsrfTokenManager csrfTokenManager;

  /// Logger instance for CSRF interceptor operations
  static final _logger = AppLogger.network();

  /// List of path patterns to exclude from CSRF protection
  ///
  /// **Why exclude paths:**
  /// - Auth endpoints (login, register) don't need CSRF (stateless)
  /// - CSRF endpoint itself (avoid infinite loop)
  /// - Public endpoints that don't modify state
  ///
  /// **Example:**
  /// ```dart
  /// excludedPaths: [
  ///   '/users/auth',      // Login endpoint
  ///   '/users/refresh',   // Token refresh
  ///   '/auth/csrf',       // CSRF token endpoint (avoid loop)
  /// ]
  /// ```
  final List<String> excludedPaths;

  /// Whether to use nullable getter (returns null instead of throwing)
  ///
  /// **When to use:**
  /// - `true`: Request continues even if CSRF fetch fails (backend rejects)
  /// - `false`: Request fails immediately if CSRF fetch fails
  ///
  /// **Default:** false (fail fast)
  ///
  /// **Recommendation:** Use `true` to avoid blocking requests
  final bool useNullableGetter;

  /// Creates CSRF interceptor
  ///
  /// **Parameters:**
  /// - [csrfTokenManager]: Manager to fetch CSRF tokens (required)
  /// - [excludedPaths]: Paths to skip CSRF protection (default: empty)
  /// - [useNullableGetter]: Use null-safe token getter (default: false)
  ///
  /// **Example:**
  /// ```dart
  /// final interceptor = CsrfInterceptor(
  ///   csrfTokenManager: CsrfTokenManager(dio: csrfDio),
  ///   excludedPaths: ['/users/auth', '/auth/csrf'],
  ///   useNullableGetter: true, // Recommended for production
  /// );
  /// ```
  CsrfInterceptor({
    required this.csrfTokenManager,
    this.excludedPaths = const [],
    this.useNullableGetter = false,
  });

  /// Intercepts request and adds CSRF token for write operations
  ///
  /// **What it does:**
  /// 1. Checks if path is excluded from CSRF protection
  /// 2. Checks if request method is a write operation
  /// 3. Fetches CSRF token from manager
  /// 4. Adds token to X-CSRF-Token header
  /// 5. Forwards request to next interceptor
  ///
  /// **Flow:**
  /// ```
  /// onRequest
  ///    ↓
  /// Is path excluded? → YES → Skip CSRF, forward request
  ///    ↓ NO
  /// Is write method? → NO → Skip CSRF, forward request
  ///    ↓ YES
  /// Fetch CSRF token
  ///    ↓
  /// Add to headers
  ///    ↓
  /// Forward request
  /// ```
  ///
  /// **Parameters:**
  /// - [options]: Request options (method, path, headers, etc.)
  /// - [handler]: Handler to forward request to next interceptor
  ///
  /// **Error Handling:**
  /// - If `useNullableGetter = true`: Continues without CSRF (backend rejects)
  /// - If `useNullableGetter = false`: Throws exception, request fails
  ///
  /// **IMPROVEMENT:**
  /// - [Medium Priority] Add retry logic (currently fails on first error)
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip if path is excluded
    if (_isPathExcluded(options.path)) {
      _logger.debug('CSRF: Skipping excluded path', metadata: {
        'path': options.path,
      });
      return handler.next(options);
    }

    // Only add CSRF token for write operations
    if (_isWriteMethod(options.method)) {
      _logger.debug('CSRF: Processing write request', metadata: {
        'method': options.method,
        'path': options.path,
        'useNullableGetter': useNullableGetter,
      });

      try {
        // Fetch CSRF token
        final token = useNullableGetter
            ? await csrfTokenManager.getTokenOrNull()
            : await csrfTokenManager.getToken();

        // Add to headers if token is available
        if (token != null && token.isNotEmpty) {
          options.headers['X-CSRF-Token'] = token;
          _logger.info('CSRF token added to request headers');
        } else {
          _logger.warning('No CSRF token available (token was null)');
        }
      } catch (e) {
        _logger.error('Failed to get CSRF token', error: e, metadata: {
          'method': options.method,
          'path': options.path,
        });
        // Continue without CSRF token on error
        // The backend will reject the request if CSRF is required
      }
    }

    handler.next(options);
  }

  /// Checks if request method requires CSRF protection
  ///
  /// **What it does:**
  /// - Returns true for write operations (POST, PUT, DELETE, PATCH)
  /// - Returns false for read operations (GET, HEAD, OPTIONS)
  ///
  /// **Why:**
  /// - CSRF attacks target state-changing operations only
  /// - Read operations are safe (no server-side changes)
  /// - Follows REST and HTTP best practices
  ///
  /// **Parameters:**
  /// - [method]: HTTP method (GET, POST, etc.)
  ///
  /// **Returns:** true if method requires CSRF, false otherwise
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

  /// Checks if path should be excluded from CSRF protection
  ///
  /// **What it does:**
  /// - Checks if request path contains any excluded pattern
  /// - Uses substring matching (path.contains)
  ///
  /// **Why substring matching:**
  /// - Flexible (matches '/api/v1/users/auth' with '/users/auth')
  /// - Simple implementation
  /// - Works with different API versions
  ///
  /// **Parameters:**
  /// - [path]: Request path (e.g., '/users/auth', '/orders/123')
  ///
  /// **Returns:** true if path should be excluded, false otherwise
  ///
  /// **Example:**
  /// ```dart
  /// // excludedPaths = ['/users/auth', '/auth/csrf']
  /// _isPathExcluded('/api/v1/users/auth')  // → true
  /// _isPathExcluded('/auth/csrf')          // → true
  /// _isPathExcluded('/orders')             // → false
  /// ```
  ///
  /// **IMPROVEMENT:**
  /// - [Medium Priority] Use regex or exact matching instead of contains
  /// - Current implementation may have false positives
  /// - Example: '/users/authenticate' matches '/users/auth' unintentionally
  bool _isPathExcluded(String path) =>
      excludedPaths.any((excludedPath) => path.contains(excludedPath));
}
