import 'package:dio/dio.dart';

/// Interceptor to handle authentication headers
class AuthInterceptor extends Interceptor {
  final String? Function() getAuthToken;
  final String? Function() getCsrfToken;

  AuthInterceptor({
    required this.getAuthToken,
    required this.getCsrfToken,
  });

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

  bool _isWriteMethod(String method) {
    final upperMethod = method.toUpperCase();
    return upperMethod == 'POST' ||
        upperMethod == 'PUT' ||
        upperMethod == 'DELETE' ||
        upperMethod == 'PATCH';
  }
}