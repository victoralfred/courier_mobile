import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../config/environment.dart';
import '../security/certificate_pinner.dart';
import 'csrf_token_manager.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/csrf_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'interceptors/request_interceptor.dart';

/// Main API client for making HTTP requests to the backend
class ApiClient {
  final Dio _dio;
  final AppEnvironment _config;
  final CertificatePinner? _certificatePinner;
  final CsrfTokenManager? _csrfTokenManager;

  String? _authToken;
  String? _refreshToken;

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

  /// Factory constructor for development environment
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

  /// Factory constructor for staging environment
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

  /// Factory constructor for production environment
  factory ApiClient.production({
    CertificatePinner? certificatePinner,
    CsrfTokenManager? csrfTokenManager,
  }) {
    AppConfig.setEnvironment(Environment.production);
    return ApiClient._(
      dio: Dio(),
      config: AppConfig.config,
      certificatePinner: certificatePinner,
      csrfTokenManager: csrfTokenManager,
    );
  }

  /// Factory constructor for custom configuration (mainly for testing)
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

  /// Get the base URL based on environment
  String get baseUrl => _config.apiBaseUrl;

  /// Get the Dio instance for testing purposes
  @visibleForTesting
  Dio get dio => _dio;

  /// Get the current auth token
  String? getAuthToken() => _authToken;

  /// Set the CSRF token manager (used for circular dependency resolution)
  void setCsrfTokenManager(CsrfTokenManager manager) {
    // Remove existing CSRF interceptor if any
    _dio.interceptors.removeWhere((i) => i is CsrfInterceptor);

    // Add new CSRF interceptor
    _dio.interceptors.add(
      CsrfInterceptor(
        csrfTokenManager: manager,
        useNullableGetter: true, // Use getTokenOrNull to avoid exceptions
        excludedPaths: [
          '/api/v1/users/auth',
          '/api/v1/users/refresh',
          '/api/v1/auth/csrf',
        ],
      ),
    );
  }

  /// Configure Dio with base options and interceptors
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

    // Add interceptors
    final interceptors = [
      RequestInterceptor(),
      AuthInterceptor(
        getAuthToken: () => _authToken,
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
            '/api/v1/users/auth',
            '/api/v1/users/refresh',
            '/api/v1/auth/csrf',
          ],
        ),
      );
    }

    interceptors.addAll([
      LoggingInterceptor(isDebug: _config.enableLogging),
      ErrorInterceptor(
        onTokenExpired: _handleTokenExpired,
      ),
    ]);

    _dio.interceptors.addAll(interceptors);
  }

  /// Set the authentication token
  void setAuthToken(String? token, {String? refreshToken}) {
    _authToken = token;
    if (refreshToken != null) {
      _refreshToken = refreshToken;
    }
  }

  /// Clear all tokens
  void clearTokens() {
    _authToken = null;
    _refreshToken = null;
    // Note: CSRF tokens are ephemeral and not cached, so no need to clear
  }

  /// Handle token expiration (retry with refresh)
  Future<void> _handleTokenExpired() async {
    try {
      // Attempt to refresh the token
      final refreshToken = _refreshToken;
      if (refreshToken != null && refreshToken.isNotEmpty) {
        // Call refresh endpoint
        final response = await _dio.post(
          '/auth/refresh',
          data: {'refresh_token': refreshToken},
          options: Options(
            headers: {
              'Authorization': 'Bearer $refreshToken',
            },
          ),
        );

        if (response.statusCode == 200 && response.data != null) {
          // Extract new tokens from response
          final data = response.data as Map<String, dynamic>;
          final newAccessToken = data['access_token'] as String?;
          final newRefreshToken = data['refresh_token'] as String?;

          if (newAccessToken != null) {
            // Update stored tokens
            _authToken = newAccessToken;
            if (newRefreshToken != null) {
              _refreshToken = newRefreshToken;
            }
            return; // Successfully refreshed
          }
        }
      }
    } catch (e) {
      // Log refresh failure (error reporting service should be used here)
      debugPrint('Token refresh failed: $e');
    }

    // If refresh fails, clear tokens and force re-authentication
    clearTokens();
  }

  /// GET request
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

  /// POST request
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

  /// PUT request
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

  /// DELETE request
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

  /// PATCH request
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

  /// Download file
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