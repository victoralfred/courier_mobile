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
    // Add Bearer token if available
    final authToken = getAuthToken();
    if (authToken != null && authToken.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $authToken';
    }

    // Add CSRF token for write operations (POST, PUT, DELETE, PATCH)
    final csrfToken = getCsrfToken();
    if (csrfToken != null &&
        csrfToken.isNotEmpty &&
        _isWriteMethod(options.method)) {
      options.headers['X-CSRF-Token'] = csrfToken;
    }

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