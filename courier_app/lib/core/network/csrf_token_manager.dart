import 'package:dio/dio.dart';
import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:delivery_app/core/error/exceptions.dart';

/// Manages CSRF tokens for API requests requiring CSRF protection
///
/// Fetches CSRF tokens from the backend and caches them to avoid
/// unnecessary API calls. Tokens are automatically refreshed when expired.
class CsrfTokenManager {
  final Dio dio;
  final String? Function()? getAuthToken;
  static const String _csrfEndpoint = '/api/v1/auth/csrf';
  static const Duration _defaultCacheDuration = Duration(minutes: 10);

  String? _cachedToken;
  DateTime? _tokenExpiryTime;
  final Duration _cacheDuration;

  CsrfTokenManager({
    required this.dio,
    this.getAuthToken,
    Duration? cacheDuration,
  }) : _cacheDuration = cacheDuration ?? _defaultCacheDuration;

  /// Get CSRF token, fetching from API if not cached or expired
  ///
  /// Throws [ServerException] if API returns error
  /// Throws [NetworkException] if network connection fails
  Future<String> getToken() async {
    // Return cached token if still valid
    if (_isCacheValid()) {
      return _cachedToken!;
    }

    // Fetch new token from API
    try {
      // Add auth token if available
      final authToken = getAuthToken?.call();
      final options = Options();
      if (authToken != null && authToken.isNotEmpty) {
        options.headers = {'Authorization': 'Bearer $authToken'};
      }

      final response = await dio.get(_csrfEndpoint, options: options);

      // Validate response structure
      final data = response.data;
      if (data is! Map<String, dynamic> ||
          data['data'] is! Map<String, dynamic> ||
          data['data']['token'] is! String) {
        throw ServerException(
          message: AppStrings.errorCsrfTokenNotFound,
          code: response.statusCode?.toString(),
        );
      }

      // Extract and cache token
      final token = data['data']['token'] as String;
      _cacheToken(token);

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

  /// Clear the cached CSRF token
  ///
  /// Forces next [getToken] call to fetch a fresh token from the API
  void clearCache() {
    _cachedToken = null;
    _tokenExpiryTime = null;
  }

  /// Check if there is a cached token available
  ///
  /// Returns true if token is cached and not expired
  bool hasCachedToken() => _isCacheValid();

  /// Cache the token with expiry time
  void _cacheToken(String token) {
    _cachedToken = token;
    _tokenExpiryTime = DateTime.now().add(_cacheDuration);
  }

  /// Check if cached token is still valid
  bool _isCacheValid() {
    if (_cachedToken == null || _tokenExpiryTime == null) {
      return false;
    }

    return DateTime.now().isBefore(_tokenExpiryTime!);
  }
}
