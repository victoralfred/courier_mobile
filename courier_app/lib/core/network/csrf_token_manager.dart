import 'package:dio/dio.dart';
import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:delivery_app/core/error/exceptions.dart';

/// Manages CSRF tokens for API requests requiring CSRF protection
///
/// Fetches fresh CSRF tokens from the backend for each mutating operation.
/// CSRF tokens are ephemeral and not cached - each request gets a new token.
class CsrfTokenManager {
  final Dio dio;
  final String? Function()? getAuthToken;
  static const String _csrfEndpoint = '/auth/csrf';

  CsrfTokenManager({
    required this.dio,
    this.getAuthToken,
  });

  /// Get CSRF token - fetches fresh token for each request
  ///
  /// CSRF tokens are ephemeral and should not be cached.
  /// Each mutating operation should use a fresh CSRF token.
  ///
  /// Throws [ServerException] if API returns error
  /// Throws [NetworkException] if network connection fails
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
      // Re-throw ServerException as-is
      rethrow;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw const NetworkException(
          message: AppStrings.errorConnectionTimeout,
        );
      }

      // Extract error message from response if available
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
      throw const ServerException(
        message: AppStrings.errorCsrfTokenFailed,
      );
    }
  }

  /// Get CSRF token or null if fetch fails
  ///
  /// Unlike [getToken], this method returns null instead of throwing
  /// exceptions, useful for optional CSRF token scenarios.
  Future<String?> getTokenOrNull() async {
    try {
      return await getToken();
    } catch (_) {
      return null;
    }
  }
}
