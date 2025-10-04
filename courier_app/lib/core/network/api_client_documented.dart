import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../features/auth/domain/entities/jwt_token.dart';
import '../config/app_config.dart';
import '../config/environment.dart';
import '../security/certificate_pinner.dart';
import 'csrf_token_manager.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/csrf_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'interceptors/request_interceptor.dart';

/// [ApiClient] - Centralized HTTP client for all backend API communications
///
/// **What it does:**
/// - Provides a unified interface for making HTTP requests (GET, POST, PUT, DELETE, PATCH)
/// - Manages authentication tokens (JWT access and refresh tokens)
/// - Automatically injects CSRF tokens for write operations
/// - Handles SSL certificate pinning for enhanced security
/// - Configures request/response interceptors for logging, auth, and error handling
/// - Supports multiple environments (development, staging, production)
/// - Implements automatic token refresh on 401 (Unauthorized) responses
///
/// **Why it exists:**
/// - Centralizes all API configuration in one place (DRY principle)
/// - Provides consistent error handling across the app
/// - Simplifies token management for authentication
/// - Ensures security best practices (CSRF, SSL pinning)
/// - Enables environment-specific configurations
/// - Makes testing easier with custom configuration support
///
/// **Architecture:**
/// ```
/// ┌─────────────┐
/// │  ApiClient  │
/// └──────┬──────┘
///        │
///        ├──► Dio (HTTP client)
///        ├──► Interceptors
///        │    ├── RequestInterceptor (pre-process requests)
///        │    ├── AuthInterceptor (inject JWT)
///        │    ├── CsrfInterceptor (inject CSRF tokens)
///        │    ├── LoggingInterceptor (debug logging)
///        │    └── ErrorInterceptor (handle errors, retry logic)
///        │
///        ├──► CertificatePinner (SSL pinning)
///        └──► CsrfTokenManager (CSRF token fetching)
/// ```
///
/// **Usage Example:**
/// ```dart
/// // Development environment
/// final apiClient = ApiClient.development(
///   certificatePinner: CertificatePinner(hashes: ['sha256/...']),
///   csrfTokenManager: CsrfTokenManager(dio),
/// );
///
/// // Set auth tokens after login
/// apiClient.setAuthToken(
///   'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
///   refreshToken: 'refresh_token_here',
/// );
///
/// // Make authenticated request
/// final response = await apiClient.get('/users/profile');
/// if (response.statusCode == 200) {
///   final profile = response.data;
///   // Use profile data
/// }
///
/// // Clear tokens on logout
/// apiClient.clearTokens();
/// ```
///
/// **IMPROVEMENT:**
/// - [High Priority] Add request retry mechanism with exponential backoff for network failures
/// - [High Priority] Implement request queuing for offline mode (currently handled at repository level)
/// - [Medium Priority] Add metrics/analytics for API performance monitoring
/// - [Medium Priority] Implement request deduplication to prevent duplicate in-flight requests
/// - [Low Priority] Add request cancellation support using CancelToken groups
/// - [Low Priority] Consider adding GraphQL support alongside REST
class ApiClient {
  /// Dio HTTP client instance - handles actual network requests
  final Dio _dio;

  /// Environment configuration (dev/staging/prod)
  final AppEnvironment _config;

  /// Optional SSL certificate pinner for enhanced security
  final CertificatePinner? _certificatePinner;

  /// Optional CSRF token manager for CSRF protection
  final CsrfTokenManager? _csrfTokenManager;

  /// Current JWT token object - contains access token, refresh token, and expiry metadata
  JwtToken? _jwtToken;

  /// Private constructor - use factory methods to create instances
  ///
  /// **Why private:**
  /// - Enforces use of factory methods for proper initialization
  /// - Ensures environment is set before configuration
  /// - Allows for different initialization strategies
  ApiClient._({
    required Dio dio,
    required AppEnvironment config,
    CertificatePinner? certificatePinner,
    CsrfTokenManager? csrfTokenManager,
  })  : _dio = dio,
        _config = config,
        _certificatePinner = certificatePinner,
        _csrfTokenManager = csrfTokenManager {
    _configureDio();
  }

  /// Creates ApiClient for development environment
  ///
  /// **What it does:**
  /// - Sets global environment to development
  /// - Configures API client with dev settings
  /// - Enables verbose logging
  ///
  /// **Parameters:**
  /// - [certificatePinner]: Optional SSL certificate validator
  /// - [csrfTokenManager]: Optional CSRF token fetcher
  ///
  /// **Example:**
  /// ```dart
  /// final client = ApiClient.development(
  ///   csrfTokenManager: CsrfTokenManager(dio),
  /// );
  /// ```
  factory ApiClient.development({
    CertificatePinner? certificatePinner,
    CsrfTokenManager? csrfTokenManager,
  }) {
    AppConfig.setEnvironment(Environment.development);
    return ApiClient._(
      dio: Dio(),
      config: AppConfig.config,
      certificatePinner: certificatePinner,
      csrfTokenManager: csrfTokenManager,
    );
  }

  /// Creates ApiClient for staging environment
  ///
  /// **What it does:**
  /// - Sets global environment to staging
  /// - Configures API client with staging settings
  /// - Points to staging backend URL
  ///
  /// **Parameters:**
  /// - [certificatePinner]: Optional SSL certificate validator
  /// - [csrfTokenManager]: Optional CSRF token fetcher
  ///
  /// **Example:**
  /// ```dart
  /// final client = ApiClient.staging(
  ///   certificatePinner: CertificatePinner(hashes: stagingHashes),
  /// );
  /// ```
  factory ApiClient.staging({
    CertificatePinner? certificatePinner,
    CsrfTokenManager? csrfTokenManager,
  }) {
    AppConfig.setEnvironment(Environment.staging);
    return ApiClient._(
      dio: Dio(),
      config: AppConfig.config,
      certificatePinner: certificatePinner,
      csrfTokenManager: csrfTokenManager,
    );
  }

  /// Creates ApiClient for production environment
  ///
  /// **What it does:**
  /// - Sets global environment to production
  /// - Configures API client with production settings
  /// - Points to production backend URL
  /// - Disables debug logging
  ///
  /// **Parameters:**
  /// - [certificatePinner]: **REQUIRED** for production - SSL pinning
  /// - [csrfTokenManager]: **REQUIRED** for production - CSRF protection
  ///
  /// **Example:**
  /// ```dart
  /// final client = ApiClient.production(
  ///   certificatePinner: CertificatePinner(hashes: prodHashes),
  ///   csrfTokenManager: CsrfTokenManager(dio),
  /// );
  /// ```
  ///
  /// **Security:**
  /// - certificatePinner: REQUIRED - SSL certificate pinning for man-in-the-middle protection
  /// - csrfTokenManager: REQUIRED - CSRF token management for cross-site request forgery protection
  ///
  /// **IMPROVEMENT:**
  /// - [Low Priority] Add compile-time check to ensure security features are enabled in release builds
  factory ApiClient.production({
    required CertificatePinner certificatePinner,
    required CsrfTokenManager csrfTokenManager,
  }) {
    AppConfig.setEnvironment(Environment.production);
    return ApiClient._(
      dio: Dio(),
      config: AppConfig.config,
      certificatePinner: certificatePinner,
      csrfTokenManager: csrfTokenManager,
    );
  }

  /// Creates ApiClient with custom configuration
  ///
  /// **What it does:**
  /// - Allows complete control over Dio and config
  /// - Primarily used for testing with mocked Dio
  ///
  /// **Why:**
  /// - Testing requires injecting mocked Dio instances
  /// - Allows for custom environment configurations
  ///
  /// **Parameters:**
  /// - [dio]: Custom Dio instance (usually mocked for tests)
  /// - [config]: Custom environment configuration
  /// - [certificatePinner]: Optional SSL validator
  /// - [csrfTokenManager]: Optional CSRF manager
  ///
  /// **Example:**
  /// ```dart
  /// // In tests
  /// final mockDio = MockDio();
  /// final client = ApiClient.custom(
  ///   dio: mockDio,
  ///   config: testConfig,
  /// );
  /// ```
  factory ApiClient.custom({
    required Dio dio,
    required AppEnvironment config,
    CertificatePinner? certificatePinner,
    CsrfTokenManager? csrfTokenManager,
  }) =>
      ApiClient._(
        dio: dio,
        config: config,
        certificatePinner: certificatePinner,
        csrfTokenManager: csrfTokenManager,
      );

  /// Gets the base URL for the current environment
  ///
  /// **Returns:** Base API URL (e.g., 'https://api.example.com/api/v1')
  String get baseUrl => _config.apiBaseUrl;

  /// Exposes Dio instance for testing purposes only
  ///
  /// **Why @visibleForTesting:**
  /// - Tests need to verify Dio configuration
  /// - Should not be used in production code
  ///
  /// **Returns:** Internal Dio instance
  @visibleForTesting
  Dio get dio => _dio;

  /// Gets the current authentication token
  ///
  /// **What it does:**
  /// - Returns the stored JWT access token
  ///
  /// **Returns:** Current auth token or null if not authenticated
  ///
  /// **Example:**
  /// ```dart
  /// if (apiClient.getAuthToken() != null) {
  ///   // User is authenticated
  /// }
  /// ```
  JwtToken? getAuthToken() => _jwtToken;

  /// Sets CSRF token manager after initialization
  ///
  /// **What it does:**
  /// - Removes existing CSRF interceptor if present
  /// - Adds new CSRF interceptor with provided manager
  ///
  /// **Why it exists:**
  /// - Resolves circular dependency (ApiClient → CsrfTokenManager → Dio)
  /// - Allows late binding of CSRF manager
  ///
  /// **Parameters:**
  /// - [manager]: CSRF token manager instance
  ///
  /// **Example:**
  /// ```dart
  /// // After creating ApiClient
  /// final csrfManager = CsrfTokenManager(separateDio);
  /// apiClient.setCsrfTokenManager(csrfManager);
  /// ```
  ///
  /// **IMPROVEMENT:**
  /// - [Medium Priority] Consider using dependency injection container instead
  /// - This pattern is a workaround for circular dependency and could be refactored
  void setCsrfTokenManager(CsrfTokenManager manager) {
    // Remove existing CSRF interceptor if any
    _dio.interceptors.removeWhere((i) => i is CsrfInterceptor);

    // Add new CSRF interceptor
    _dio.interceptors.add(
      CsrfInterceptor(
        csrfTokenManager: manager,
        useNullableGetter: true, // Use getTokenOrNull to avoid exceptions
        excludedPaths: [
          '/users/auth',
          '/users/refresh',
          '/auth/csrf',
        ],
      ),
    );
  }

  /// Configures Dio with interceptors and base options
  ///
  /// **What it does:**
  /// 1. Configures SSL certificate pinning if provided
  /// 2. Sets base URL, timeouts, and headers
  /// 3. Adds interceptor chain:
  ///    - RequestInterceptor (request pre-processing)
  ///    - AuthInterceptor (JWT injection)
  ///    - CsrfInterceptor (CSRF token injection for write ops)
  ///    - LoggingInterceptor (request/response logging)
  ///    - ErrorInterceptor (error handling + token refresh)
  ///
  /// **Why this order:**
  /// - Request processing happens first
  /// - Auth headers added before CSRF
  /// - CSRF added before logging (so it's logged)
  /// - Error handling happens last to catch all errors
  ///
  /// **IMPROVEMENT:**
  /// - [Low Priority] Consider making validateStatus more restrictive
  /// - Currently accepts all 4xx errors, might want to handle some as exceptions
  void _configureDio() {
    // Configure certificate pinning if provided
    if (_certificatePinner != null) {
      _certificatePinner!.configureDio(_dio);
    }

    // Set base options
    _dio.options = BaseOptions(
      baseUrl: _config.apiBaseUrl,
      connectTimeout: _config.connectionTimeout,
      receiveTimeout: _config.receiveTimeout,
      sendTimeout: _config.connectionTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      validateStatus: (status) => status != null && status < 500,
    );

    // Build interceptor chain
    final interceptors = [
      RequestInterceptor(),
      AuthInterceptor(
        getAuthToken: () => _jwtToken,
        getCsrfToken: () => null, // Deprecated - using CsrfInterceptor instead
      ),
    ];

    // Add CSRF interceptor if manager is provided
    if (_csrfTokenManager != null) {
      interceptors.add(
        CsrfInterceptor(
          csrfTokenManager: _csrfTokenManager!,
          useNullableGetter: true, // Use getTokenOrNull to avoid exceptions
          excludedPaths: [
            '/users/auth',
            '/users/refresh',
            '/auth/csrf',
          ],
        ),
      );
    }

    // Add logging and error handling
    interceptors.addAll([
      LoggingInterceptor(isDebug: _config.enableLogging),
      ErrorInterceptor(
        onTokenExpired: _handleTokenExpired,
      ),
    ]);

    _dio.interceptors.addAll(interceptors);
  }

  /// Sets authentication tokens
  ///
  /// **What it does:**
  /// - Stores JWT access token for Authorization header
  /// - Optionally stores refresh token for token renewal
  ///
  /// **Parameters:**
  /// - [token]: JWT access token (injected in Authorization: Bearer {token})
  /// - [refreshToken]: Optional JWT refresh token for renewal
  ///
  /// **Example:**
  /// ```dart
  /// // After successful login
  /// apiClient.setAuthToken(
  ///   loginResponse.accessToken,
  ///   refreshToken: loginResponse.refreshToken,
  /// );
  /// ```
  void setAuthToken(JwtToken? token) {
    _jwtToken = token;
  }

  /// Clears all authentication tokens
  ///
  /// **What it does:**
  /// - Removes access token
  /// - Removes refresh token
  /// - Does NOT clear CSRF tokens (they're ephemeral and fetched per-request)
  ///
  /// **When to use:**
  /// - User logs out
  /// - Token refresh fails permanently
  /// - Security breach detected
  ///
  /// **Example:**
  /// ```dart
  /// // On logout
  /// await authRepository.logout();
  /// apiClient.clearTokens();
  /// ```
  void clearTokens() {
    _jwtToken = null;
    // Note: CSRF tokens are ephemeral and not cached, so no need to clear
  }

  /// Handles token expiration by attempting refresh
  ///
  /// **What it does:**
  /// 1. Attempts to refresh access token using refresh token
  /// 2. Calls POST /users/refresh with refresh token
  /// 3. Updates stored tokens if successful
  /// 4. Clears all tokens if refresh fails
  ///
  /// **Why:**
  /// - Provides seamless user experience (no re-login on token expiry)
  /// - Implements OAuth2 refresh token flow
  ///
  /// **Flow:**
  /// ```
  /// 401 Unauthorized
  ///     ↓
  /// ErrorInterceptor detects
  ///     ↓
  /// _handleTokenExpired() called
  ///     ↓
  /// POST /users/refresh
  ///     ↓
  /// ├─ Success → Update tokens
  /// └─ Failure → Clear tokens (force re-login)
  /// ```
  ///
  /// **IMPROVEMENT:**
  /// - [High Priority] Add mutex/lock to prevent concurrent refresh attempts
  /// - [High Priority] Queue failed requests and retry after successful refresh
  /// - [Medium Priority] Implement exponential backoff for refresh retries
  /// - [Low Priority] Emit stream event for UI to show "refreshing session" message
  Future<void> _handleTokenExpired() async {
    // Token refresh is now handled by TokenManager
    // This method is deprecated but kept for backward compatibility
    // Simply clear tokens to force re-authentication
    clearTokens();
  }

  /// Performs HTTP GET request
  ///
  /// **What it does:**
  /// - Sends GET request to specified path
  /// - Automatically includes auth token if set
  /// - Returns typed response
  ///
  /// **Parameters:**
  /// - [path]: API endpoint (relative to baseUrl)
  /// - [queryParameters]: URL query params as Map
  /// - [options]: Custom Dio options (headers, etc.)
  /// - [cancelToken]: Token to cancel request
  /// - [onReceiveProgress]: Progress callback for downloads
  ///
  /// **Returns:** Dio Response with data of type T
  ///
  /// **Example:**
  /// ```dart
  /// // Get user profile
  /// final response = await apiClient.get<Map<String, dynamic>>(
  ///   '/users/profile',
  ///   queryParameters: {'include': 'settings'},
  /// );
  ///
  /// if (response.statusCode == 200) {
  ///   final userData = response.data;
  /// }
  /// ```
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) =>
      _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );

  /// Performs HTTP POST request
  ///
  /// **What it does:**
  /// - Sends POST request with body data
  /// - Automatically includes auth token
  /// - Automatically includes CSRF token (via CsrfInterceptor)
  ///
  /// **Parameters:**
  /// - [path]: API endpoint (relative to baseUrl)
  /// - [data]: Request body (will be JSON encoded)
  /// - [queryParameters]: URL query params
  /// - [options]: Custom Dio options
  /// - [cancelToken]: Token to cancel request
  /// - [onSendProgress]: Upload progress callback
  /// - [onReceiveProgress]: Download progress callback
  ///
  /// **Returns:** Dio Response with data of type T
  ///
  /// **Example:**
  /// ```dart
  /// // Create new order
  /// final response = await apiClient.post<Map<String, dynamic>>(
  ///   '/orders',
  ///   data: {
  ///     'pickup_address': '123 Main St',
  ///     'delivery_address': '456 Oak Ave',
  ///     'package_details': {...},
  ///   },
  /// );
  /// ```
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) =>
      _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );

  /// Performs HTTP PUT request
  ///
  /// **What it does:**
  /// - Sends PUT request to update resource
  /// - Automatically includes auth token
  /// - Automatically includes CSRF token
  ///
  /// **Parameters:**
  /// - [path]: API endpoint (relative to baseUrl)
  /// - [data]: Request body with updates
  /// - [queryParameters]: URL query params
  /// - [options]: Custom Dio options
  /// - [cancelToken]: Token to cancel request
  /// - [onSendProgress]: Upload progress callback
  /// - [onReceiveProgress]: Download progress callback
  ///
  /// **Returns:** Dio Response with data of type T
  ///
  /// **Example:**
  /// ```dart
  /// // Update driver location
  /// final response = await apiClient.put(
  ///   '/drivers/$driverId/location',
  ///   data: {
  ///     'latitude': 37.7749,
  ///     'longitude': -122.4194,
  ///     'timestamp': DateTime.now().toIso8601String(),
  ///   },
  /// );
  /// ```
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) =>
      _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );

  /// Performs HTTP DELETE request
  ///
  /// **What it does:**
  /// - Sends DELETE request to remove resource
  /// - Automatically includes auth token
  /// - Automatically includes CSRF token
  ///
  /// **Parameters:**
  /// - [path]: API endpoint (relative to baseUrl)
  /// - [data]: Optional request body
  /// - [queryParameters]: URL query params
  /// - [options]: Custom Dio options
  /// - [cancelToken]: Token to cancel request
  ///
  /// **Returns:** Dio Response with data of type T
  ///
  /// **Example:**
  /// ```dart
  /// // Delete driver application
  /// final response = await apiClient.delete(
  ///   '/drivers/$driverId',
  /// );
  ///
  /// if (response.statusCode == 200) {
  ///   // Application deleted successfully
  /// }
  /// ```
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) =>
      _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );

  /// Performs HTTP PATCH request
  ///
  /// **What it does:**
  /// - Sends PATCH request for partial updates
  /// - Automatically includes auth token
  /// - Automatically includes CSRF token
  ///
  /// **Parameters:**
  /// - [path]: API endpoint (relative to baseUrl)
  /// - [data]: Partial update data
  /// - [queryParameters]: URL query params
  /// - [options]: Custom Dio options
  /// - [cancelToken]: Token to cancel request
  /// - [onSendProgress]: Upload progress callback
  /// - [onReceiveProgress]: Download progress callback
  ///
  /// **Returns:** Dio Response with data of type T
  ///
  /// **Example:**
  /// ```dart
  /// // Update only driver availability
  /// final response = await apiClient.patch(
  ///   '/drivers/$driverId/availability',
  ///   data: {'availability': 'available'},
  /// );
  /// ```
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) =>
      _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );

  /// Downloads file from server
  ///
  /// **What it does:**
  /// - Downloads file to specified path
  /// - Supports progress tracking
  /// - Automatically includes auth token
  ///
  /// **Parameters:**
  /// - [urlPath]: URL to download from
  /// - [savePath]: Local path to save file
  /// - [onReceiveProgress]: Download progress callback
  /// - [queryParameters]: URL query params
  /// - [cancelToken]: Token to cancel download
  /// - [deleteOnError]: Delete partial file if error occurs
  /// - [lengthHeader]: Header for content length
  /// - [data]: Optional request body
  /// - [options]: Custom Dio options
  ///
  /// **Returns:** Dio Response
  ///
  /// **Example:**
  /// ```dart
  /// // Download invoice PDF
  /// await apiClient.download(
  ///   '/orders/$orderId/invoice',
  ///   '/storage/invoices/invoice_$orderId.pdf',
  ///   onReceiveProgress: (received, total) {
  ///     print('Progress: ${(received / total * 100).toStringAsFixed(0)}%');
  ///   },
  /// );
  /// ```
  ///
  /// **IMPROVEMENT:**
  /// - [Medium Priority] Add resume capability for interrupted downloads
  /// - [Low Priority] Implement file integrity verification (checksum)
  Future<Response> download(
    String urlPath,
    String savePath, {
    ProgressCallback? onReceiveProgress,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    bool deleteOnError = true,
    String lengthHeader = Headers.contentLengthHeader,
    dynamic data,
    Options? options,
  }) =>
      _dio.download(
        urlPath,
        savePath,
        onReceiveProgress: onReceiveProgress,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        deleteOnError: deleteOnError,
        lengthHeader: lengthHeader,
        data: data,
        options: options,
      );
}
