import 'package:dio/dio.dart';
import 'package:delivery_app/core/network/csrf_token_manager.dart';

/// Interceptor to automatically add CSRF tokens to write operations
///
/// Fetches CSRF tokens from [CsrfTokenManager] and injects them into
/// request headers for POST, PUT, DELETE, and PATCH methods.
class CsrfInterceptor extends Interceptor {
  final CsrfTokenManager csrfTokenManager;
  final List<String> excludedPaths;
  final bool useNullableGetter;

  CsrfInterceptor({
    required this.csrfTokenManager,
    this.excludedPaths = const [],
    this.useNullableGetter = false,
  });

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip if path is excluded
    if (_isPathExcluded(options.path)) {
      return handler.next(options);
    }

    // Only add CSRF token for write operations
    if (_isWriteMethod(options.method)) {
      try {
        // Fetch CSRF token
        final token = useNullableGetter
            ? await csrfTokenManager.getTokenOrNull()
            : await csrfTokenManager.getToken();

        // Add to headers if token is available
        if (token != null && token.isNotEmpty) {
          options.headers['X-CSRF-Token'] = token;
        }
      } catch (e) {
        // Continue without CSRF token on error
        // The backend will reject the request if CSRF is required
      }
    }

    handler.next(options);
  }

  /// Check if the request method requires CSRF protection
  bool _isWriteMethod(String method) {
    final upperMethod = method.toUpperCase();
    return upperMethod == 'POST' ||
        upperMethod == 'PUT' ||
        upperMethod == 'DELETE' ||
        upperMethod == 'PATCH';
  }

  /// Check if the path should be excluded from CSRF protection
  bool _isPathExcluded(String path) =>
      excludedPaths.any((excludedPath) => path.contains(excludedPath));
}
