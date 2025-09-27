import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../config/environment.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'interceptors/request_interceptor.dart';

/// Main API client for making HTTP requests to the backend
class ApiClient {
  final Dio _dio;
  final EnvironmentConfig _config;

  String? _authToken;
  String? _csrfToken;

  ApiClient._({
    required Dio dio,
    required EnvironmentConfig config,
  })  : _dio = dio,
        _config = config {
    _configureDio();
  }

  /// Factory constructor for development environment
  factory ApiClient.development() {
    AppConfig.setEnvironment(Environment.development);
    return ApiClient._(
      dio: Dio(),
      config: AppConfig.config,
    );
  }

  /// Factory constructor for staging environment
  factory ApiClient.staging() {
    AppConfig.setEnvironment(Environment.staging);
    return ApiClient._(
      dio: Dio(),
      config: AppConfig.config,
    );
  }

  /// Factory constructor for production environment
  factory ApiClient.production() {
    AppConfig.setEnvironment(Environment.production);
    return ApiClient._(
      dio: Dio(),
      config: AppConfig.config,
    );
  }

  /// Factory constructor for custom configuration (mainly for testing)
  factory ApiClient.custom({
    required Dio dio,
    required EnvironmentConfig config,
  }) =>
      ApiClient._(dio: dio, config: config);

  /// Get the base URL based on environment
  String get baseUrl => _config.apiBaseUrl;

  /// Get the Dio instance for testing purposes
  @visibleForTesting
  Dio get dio => _dio;

  /// Configure Dio with base options and interceptors
  void _configureDio() {
    // Set base options
    _dio.options = BaseOptions(
      baseUrl: _config.apiBaseUrl,
      connectTimeout: Duration(milliseconds: _config.connectTimeout),
      receiveTimeout: Duration(milliseconds: _config.receiveTimeout),
      sendTimeout: Duration(milliseconds: _config.connectTimeout),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      validateStatus: (status) => status != null && status < 500,
    );

    // Add interceptors
    _dio.interceptors.addAll([
      RequestInterceptor(),
      AuthInterceptor(
        getAuthToken: () => _authToken,
        getCsrfToken: () => _csrfToken,
      ),
      LoggingInterceptor(isDebug: _config.enableLogging),
      ErrorInterceptor(
        onTokenExpired: _handleTokenExpired,
      ),
    ]);
  }

  /// Set the authentication token
  void setAuthToken(String? token) {
    _authToken = token;
  }

  /// Set the CSRF token
  void setCsrfToken(String? token) {
    _csrfToken = token;
  }

  /// Clear all tokens
  void clearTokens() {
    _authToken = null;
    _csrfToken = null;
  }

  /// Handle token expiration (retry with refresh)
  Future<void> _handleTokenExpired() async {
    // TODO: Implement token refresh logic
    // This will be implemented when we add authentication
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