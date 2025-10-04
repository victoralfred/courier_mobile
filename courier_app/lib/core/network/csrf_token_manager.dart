import 'package:dio/dio.dart';
import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:delivery_app/core/error/exceptions.dart';

/// [CsrfTokenManager] - Manages Cross-Site Request Forgery (CSRF) tokens for write operations
///
/// **What it does:**
/// - Fetches fresh CSRF tokens from backend `/auth/csrf` endpoint
/// - Provides tokens for POST, PUT, DELETE, PATCH requests
/// - Implements ephemeral token strategy (no caching)
/// - Handles network and server errors gracefully
/// - Optionally includes authentication token in CSRF fetch request
///
/// **Why it exists:**
/// - CSRF protection prevents unauthorized state-changing requests
/// - Ephemeral tokens provide maximum security (each request gets fresh token)
/// - Separates CSRF token fetching logic from API client
/// - Resolves circular dependency between ApiClient and CSRF management
///
/// **Security Model:**
/// ```
/// Client                    Backend
///   │                          │
///   ├─── GET /auth/csrf ──────>│
///   │<─── {csrf_token: "..."} ─┤
///   │                          │
///   ├─── POST /api/resource ──>│
///   │    (X-CSRF-Token header) │
///   │<─── Success/Failure ─────┤
/// ```
///
/// **Usage Example:**
/// ```dart
/// // Create CSRF manager with separate Dio instance
/// final csrfDio = Dio()..options.baseUrl = apiBaseUrl;
/// final csrfManager = CsrfTokenManager(
///   dio: csrfDio,
///   getAuthToken: () => currentAuthToken,
/// );
///
/// // Fetch CSRF token for write operation
/// final csrfToken = await csrfManager.getToken();
///
/// // Use with CsrfInterceptor (automatic)
/// apiClient.setCsrfTokenManager(csrfManager);
/// ```
///
/// **IMPROVEMENT:**
/// - [Medium Priority] Add token caching with 5-10 minute TTL for performance
/// - Currently fetches new token for EVERY write request (high API load)
/// - [Low Priority] Add metrics for token fetch success/failure rates
/// - [Low Priority] Implement token pre-fetching on app start
class CsrfTokenManager {
  /// Dio HTTP client instance for fetching CSRF tokens
  ///
  /// **Why separate Dio instance:**
  /// - Prevents circular dependency (ApiClient → CsrfTokenManager → ApiClient)
  /// - Avoids infinite interceptor loops
  /// - Can have different timeout/retry settings
  final Dio dio;

  /// Optional function to get current auth token
  ///
  /// **Why optional:**
  /// - Some endpoints allow CSRF without authentication
  /// - Allows flexibility in token source
  final String? Function()? getAuthToken;

  /// CSRF token endpoint path
  ///
  /// **Why constant:**
  /// - Endpoint is standardized across environments
  /// - Prevents typos and ensures consistency
  static const String _csrfEndpoint = '/auth/csrf';

  /// Creates CSRF token manager
  ///
  /// **Parameters:**
  /// - [dio]: Separate Dio instance (avoid circular dependency)
  /// - [getAuthToken]: Optional function to retrieve auth token
  ///
  /// **Example:**
  /// ```dart
  /// final manager = CsrfTokenManager(
  ///   dio: Dio()..options.baseUrl = 'https://api.example.com',
  ///   getAuthToken: () => tokenManager.getAccessToken(),
  /// );
  /// ```
  CsrfTokenManager({
    required this.dio,
    this.getAuthToken,
  });

  /// Fetches fresh CSRF token from backend
  ///
  /// **What it does:**
  /// 1. Calls GET /auth/csrf endpoint
  /// 2. Includes auth token in Authorization header if available
  /// 3. Validates response structure
  /// 4. Extracts and returns CSRF token
  ///
  /// **Why no caching:**
  /// - Ephemeral tokens provide maximum security
  /// - Prevents token replay attacks
  /// - Aligns with OWASP CSRF protection recommendations
  ///
  /// **Response Format:**
  /// ```json
  /// {
  ///   "success": true,
  ///   "data": {
  ///     "csrf_token": "abc123...",
  ///     "expires_at": "2025-10-04T12:00:00Z"
  ///   }
  /// }
  /// ```
  ///
  /// **Returns:** Fresh CSRF token string
  ///
  /// **Throws:**
  /// - [ServerException]: If backend returns error or invalid response
  /// - [NetworkException]: If network connection fails (timeout, no internet)
  ///
  /// **Example:**
  /// ```dart
  /// try {
  ///   final token = await csrfManager.getToken();
  ///   // Use token in X-CSRF-Token header
  /// } on ServerException catch (e) {
  ///   print('Server error: ${e.message}');
  /// } on NetworkException catch (e) {
  ///   print('Network error: ${e.message}');
  /// }
  /// ```
  ///
  /// **IMPROVEMENT:**
  /// - [High Priority] Remove debug print statements (use logging service)
  /// - [Medium Priority] Add retry logic (currently fails on first error)
  /// - [Low Priority] Cache token for 5-10 minutes to reduce API calls
  Future<String> getToken() async {
    // Fetch fresh token from API
    try {
      // Add auth token if available
      final authToken = getAuthToken?.call();
      print('=== CSRF TOKEN MANAGER DEBUG ===');
      print('Fetching new CSRF token from: $_csrfEndpoint');
      print('Base URL: ${dio.options.baseUrl}');
      print('Full URL: ${dio.options.baseUrl}$_csrfEndpoint');
      print('Auth token available: ${authToken != null ? "YES (${authToken.substring(0, 20)}...)" : "NO"}');

      final options = Options();
      if (authToken != null && authToken.isNotEmpty) {
        options.headers = {'Authorization': 'Bearer $authToken'};
        print('Added Authorization header to CSRF request');
      } else {
        print('⚠️  No auth token available for CSRF request!');
      }
      print('================================');

      final response = await dio.get(_csrfEndpoint, options: options);

      // Validate response structure
      final data = response.data;
      if (data is! Map<String, dynamic> ||
          data['data'] is! Map<String, dynamic> ||
          data['data']['csrf_token'] is! String) {
        throw ServerException(
          message: AppStrings.errorCsrfTokenNotFound,
          code: response.statusCode?.toString(),
        );
      }

      // Extract and return token (no caching - CSRF tokens are ephemeral)
      final token = data['data']['csrf_token'] as String;
      print('✅ Fresh CSRF token fetched');

      return token;
    } on ServerException {
      // Re-throw ServerException as-is (preserve error details)
      rethrow;
    } on DioException catch (e) {
      // Handle network-specific errors
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw const NetworkException(
          message: AppStrings.errorConnectionTimeout,
        );
      }

      // Extract error message from backend response if available
      String errorMessage = AppStrings.errorCsrfTokenFailed;
      if (e.response?.data is Map<String, dynamic>) {
        final responseData = e.response!.data as Map<String, dynamic>;
        if (responseData['error'] is Map<String, dynamic>) {
          final errorData = responseData['error'] as Map<String, dynamic>;
          errorMessage = errorData['message'] as String? ?? errorMessage;
        }
      }

      throw ServerException(
        message: errorMessage,
        code: e.response?.statusCode?.toString(),
      );
    } catch (e) {
      // Catch-all for unexpected errors
      throw const ServerException(
        message: AppStrings.errorCsrfTokenFailed,
      );
    }
  }

  /// Fetches CSRF token, returns null if fetch fails
  ///
  /// **What it does:**
  /// - Calls [getToken] internally
  /// - Catches all exceptions and returns null
  /// - Useful for optional CSRF scenarios
  ///
  /// **Why it exists:**
  /// - Some operations may gracefully degrade without CSRF
  /// - Prevents exceptions from bubbling up
  /// - Used by CsrfInterceptor with `useNullableGetter: true`
  ///
  /// **Returns:** CSRF token or null if fetch fails
  ///
  /// **Example:**
  /// ```dart
  /// final token = await csrfManager.getTokenOrNull();
  /// if (token != null) {
  ///   // Add CSRF header
  /// } else {
  ///   // Proceed without CSRF (if allowed by endpoint)
  /// }
  /// ```
  ///
  /// **IMPROVEMENT:**
  /// - [Medium Priority] Log errors even when returning null
  /// - Currently swallows all errors silently
  Future<String?> getTokenOrNull() async {
    try {
      return await getToken();
    } catch (_) {
      return null;
    }
  }
}
