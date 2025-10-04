import 'package:dio/dio.dart';
import '../../error/exceptions.dart';
import '../../constants/app_strings.dart';

/// [ErrorInterceptor] - Dio interceptor that converts HTTP errors into typed app exceptions
///
/// **What it does:**
/// - Intercepts all HTTP errors from Dio (network, timeout, server errors)
/// - Converts generic DioException into typed app exceptions (ValidationException, AuthenticationException, etc.)
/// - Parses backend error responses with standard format
/// - Maps HTTP status codes to appropriate exception types
/// - Triggers token expiration callback on 401 session expired
/// - Provides consistent error handling across the entire app
///
/// **Why it exists:**
/// - Centralizes error handling logic (DRY principle)
/// - Provides type-safe error handling (no magic strings)
/// - Separates error handling from business logic
/// - Makes errors testable and predictable
/// - Enables consistent error messages across app
/// - Simplifies error handling in repositories and BLoCs
///
/// **Error Flow:**
/// ```
/// HTTP Error → ErrorInterceptor
///                   ↓
///              Classify error type
///                   ↓
///        Network? Timeout? Server? Auth?
///                   ↓
///        Parse backend error response
///                   ↓
///        Create typed exception
///                   ↓
///        401 session expired? → Call onTokenExpired()
///                   ↓
///        Reject with typed exception → BLoC/Repository catches
/// ```
///
/// **Exception Mapping:**
/// - **Timeout/Connection errors** → NetworkException
/// - **401 Unauthorized** → AuthenticationException.unauthorized()
/// - **401 Session Expired** → AuthenticationException.sessionExpired() + callback
/// - **400 Bad Request** → ValidationException
/// - **403 Forbidden** → ServerException (403)
/// - **404 Not Found** → ServerException (404)
/// - **500+ Server errors** → ServerException
/// - **Request cancelled** → NetworkException (REQUEST_CANCELLED)
/// - **Unknown errors** → UnknownException
///
/// **Backend Error Format Expected:**
/// ```json
/// {
///   "success": false,
///   "error": {
///     "code": "VALIDATION_ERROR",
///     "message": "Invalid email format",
///     "details": {"email": ["Must be valid email"]}
///   }
/// }
/// ```
///
/// **Usage Example:**
/// ```dart
/// // Create interceptor with token expiration handler
/// final errorInterceptor = ErrorInterceptor(
///   onTokenExpired: () async {
///     // Clear tokens, navigate to login
///     await tokenManager.clearTokens();
///     router.navigateToLogin();
///   },
/// );
///
/// // Add to Dio interceptor chain
/// final dio = Dio()
///   ..interceptors.add(errorInterceptor);
///
/// // Now all errors are typed exceptions
/// try {
///   await dio.get('/users/profile');
/// } on AuthenticationException catch (e) {
///   print('Auth error: ${e.message}');
/// } on ValidationException catch (e) {
///   print('Validation errors: ${e.errors}');
/// } on NetworkException catch (e) {
///   print('Network error: ${e.message}');
/// }
/// ```
///
/// **IMPROVEMENT:**
/// - [High Priority] Add structured logging for errors (track error rates, patterns)
/// - [Medium Priority] Add retry logic for transient errors (500, 502, 503)
/// - [Medium Priority] Add custom error handling per endpoint (some endpoints have different formats)
/// - [Low Priority] Add metrics for error tracking (Sentry, Firebase Crashlytics)
/// - [Low Priority] Support circuit breaker pattern (stop requests after repeated failures)
class ErrorInterceptor extends Interceptor {
  /// Optional callback invoked when JWT token expires (401 session expired)
  ///
  /// **Why needed:**
  /// - Allows app to handle session expiration (clear tokens, navigate to login)
  /// - Decouples token management from interceptor
  /// - Enables testing token expiration flows
  ///
  /// **When called:**
  /// - Only on 401 errors with code = SESSION_EXPIRED
  /// - Not called on other 401 errors (unauthorized but token valid)
  ///
  /// **Example:**
  /// ```dart
  /// ErrorInterceptor(
  ///   onTokenExpired: () async {
  ///     await tokenManager.clearTokens();
  ///     router.navigateToLogin();
  ///   },
  /// )
  /// ```
  final Future<void> Function()? onTokenExpired;

  /// Creates error interceptor
  ///
  /// **Parameters:**
  /// - [onTokenExpired]: Optional callback for token expiration (default: null)
  ///
  /// **Example:**
  /// ```dart
  /// final interceptor = ErrorInterceptor(
  ///   onTokenExpired: () => handleSessionExpired(),
  /// );
  /// ```
  ErrorInterceptor({this.onTokenExpired});

  /// Intercepts HTTP errors and converts them to typed app exceptions
  ///
  /// **What it does:**
  /// 1. Receives DioException from Dio HTTP client
  /// 2. Converts to appropriate typed exception (_handleError)
  /// 3. Checks if error is 401 session expired
  /// 4. Calls onTokenExpired callback if session expired
  /// 5. Rejects with typed exception wrapped in DioException
  ///
  /// **Flow:**
  /// ```
  /// onError
  ///    ↓
  /// Convert to typed exception
  ///    ↓
  /// Is 401 session expired? → YES → Call onTokenExpired()
  ///    ↓ NO
  /// Reject with typed exception
  /// ```
  ///
  /// **Parameters:**
  /// - [err]: Original DioException from HTTP client
  /// - [handler]: Handler to reject with typed exception
  ///
  /// **Why wrap in DioException:**
  /// - Maintains compatibility with Dio interceptor chain
  /// - Preserves request/response metadata
  /// - Allows other interceptors to process error
  ///
  /// **Example Flow:**
  /// ```
  /// 401 Error → onError → AuthenticationException.sessionExpired()
  ///                    → onTokenExpired() called
  ///                    → Reject with exception
  ///                    → BLoC catches AuthenticationException
  /// ```
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final exception = _handleError(err);

    // Handle token expiration
    if (exception is AuthenticationException &&
        exception.code == AppStrings.errorCodeSessionExpired &&
        onTokenExpired != null) {
      await onTokenExpired!();
    }

    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: exception,
        type: err.type,
        response: err.response,
      ),
    );
  }

  /// Classifies DioException and converts to appropriate app exception
  ///
  /// **What it does:**
  /// - Examines DioException type (timeout, connection, response, etc.)
  /// - Maps each type to corresponding app exception
  /// - Delegates response errors to _handleResponseError for parsing
  ///
  /// **Exception Type Mapping:**
  /// ```
  /// DioExceptionType              →  AppException
  /// ─────────────────────────────────────────────────
  /// connectionTimeout             →  NetworkException.timeout()
  /// sendTimeout                   →  NetworkException.timeout()
  /// receiveTimeout                →  NetworkException.timeout()
  /// connectionError               →  NetworkException.noConnection()
  /// badResponse (4xx, 5xx)        →  Parse response (varies)
  /// cancel                        →  NetworkException (REQUEST_CANCELLED)
  /// unknown                       →  UnknownException
  /// ```
  ///
  /// **Parameters:**
  /// - [error]: DioException from HTTP client
  ///
  /// **Returns:** Typed app exception (NetworkException, AuthenticationException, etc.)
  ///
  /// **Why switch on error.type:**
  /// - Different error types require different handling
  /// - Network errors don't have response bodies to parse
  /// - Response errors need status code parsing
  ///
  /// **Example:**
  /// ```dart
  /// // Timeout error
  /// DioException(type: connectionTimeout) → NetworkException.timeout()
  ///
  /// // 401 response
  /// DioException(type: badResponse, response.statusCode: 401)
  ///   → _handleResponseError()
  ///   → AuthenticationException.unauthorized()
  /// ```
  AppException _handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkException.timeout();

      case DioExceptionType.connectionError:
        return NetworkException.noConnection();

      case DioExceptionType.badResponse:
        return _handleResponseError(error.response);

      case DioExceptionType.cancel:
        return const NetworkException(
          message: AppStrings.requestWasCancelled,
          code: 'REQUEST_CANCELLED',
        );

      case DioExceptionType.unknown:
      default:
        return UnknownException(
          message: error.message ?? AppStrings.errorUnknown,
          details: error.error,
        );
    }
  }

  /// Parses HTTP response error and converts to typed exception
  ///
  /// **What it does:**
  /// 1. Checks if response is null (edge case)
  /// 2. Attempts to parse backend standard error format (JSON)
  /// 3. Maps HTTP status codes to exception types
  /// 4. Falls back to status code only if parsing fails
  ///
  /// **Two-Phase Parsing:**
  /// ```
  /// Phase 1: Try standard error format
  ///   {
  ///     "error": {
  ///       "code": "VALIDATION_ERROR",
  ///       "message": "...",
  ///       "details": {...}
  ///     }
  ///   }
  ///
  /// Phase 2: Fallback to status code only
  ///   400 → ValidationException
  ///   401 → AuthenticationException
  ///   etc.
  /// ```
  ///
  /// **Status Code Mapping:**
  /// - **400**: ValidationException (bad request, field errors)
  /// - **401**: AuthenticationException (unauthorized or session expired)
  /// - **403**: ServerException (forbidden, insufficient permissions)
  /// - **404**: ServerException (resource not found)
  /// - **500-504**: ServerException (server errors)
  /// - **Other**: ServerException (generic with status message)
  ///
  /// **Parameters:**
  /// - [response]: HTTP response from Dio (may be null)
  ///
  /// **Returns:** Typed app exception based on response
  ///
  /// **Why two-phase parsing:**
  /// - Backend may not always return standard format (legacy endpoints)
  /// - Some errors may be framework-generated (nginx, load balancer)
  /// - Fallback ensures we always return typed exception
  ///
  /// **Example:**
  /// ```dart
  /// // Standard format (Phase 1)
  /// Response(
  ///   statusCode: 401,
  ///   data: {
  ///     "error": {
  ///       "code": "SESSION_EXPIRED",
  ///       "message": "Your session has expired"
  ///     }
  ///   }
  /// )
  /// → AuthenticationException.sessionExpired()
  ///
  /// // Fallback (Phase 2)
  /// Response(statusCode: 401, data: "Unauthorized")
  /// → AuthenticationException.unauthorized()
  /// ```
  ///
  /// **IMPROVEMENT:**
  /// - [Medium Priority] Add caching for parsed errors (avoid re-parsing)
  /// - [Low Priority] Support multiple error formats (different backends)
  AppException _handleResponseError(Response? response) {
    if (response == null) {
      return const UnknownException();
    }

    // Try to parse standard error response format
    if (response.data is Map<String, dynamic>) {
      final data = response.data as Map<String, dynamic>;
      if (data.containsKey('error') && data['error'] is Map<String, dynamic>) {
        final error = data['error'] as Map<String, dynamic>;

        // Check for validation errors
        if (error['code'] == AppStrings.errorCodeValidation) {
          return ValidationException.fromJson(error);
        }

        // Create appropriate exception based on status code
        switch (response.statusCode) {
          case 400:
            return ValidationException.fromJson(error);
          case 401:
            if (error['code'] == AppStrings.errorCodeSessionExpired) {
              return AuthenticationException.sessionExpired();
            }
            return AuthenticationException.unauthorized();
          case 403:
            return ServerException(
              code: AppStrings.errorCodeForbidden,
              message: error['message'] ?? AppStrings.errorForbidden,
              details: error['details'],
            );
          case 404:
            return ServerException(
              code: AppStrings.errorCodeNotFound,
              message: error['message'] ?? AppStrings.errorResourceNotFound,
              details: error['details'],
            );
          default:
            return ServerException.fromJson(error);
        }
      }
    }

    // Fallback to status code based exception
    switch (response.statusCode) {
      case 400:
        return const ValidationException();
      case 401:
        return AuthenticationException.unauthorized();
      case 403:
        return const ServerException(
          code: AppStrings.errorCodeForbidden,
          message: AppStrings.errorAccessDenied,
        );
      case 404:
        return const ServerException(
          code: AppStrings.errorCodeNotFound,
          message: AppStrings.errorResourceNotFound,
        );
      case 500:
      case 502:
      case 503:
      case 504:
        return const ServerException(
          code: AppStrings.errorCodeServerError,
          message: AppStrings.errorInternalServer,
        );
      default:
        return ServerException(
          code: response.statusCode.toString(),
          message: response.statusMessage ?? AppStrings.errorServerGeneral,
        );
    }
  }
}
