import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

/// Interceptor to add common headers to requests
class RequestInterceptor extends Interceptor {
  final _uuid = const Uuid();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Add X-Request-ID header for request tracking
    options.headers['X-Request-ID'] = _uuid.v4();

    // Add timestamp header
    options.headers['X-Request-Time'] = DateTime.now().toIso8601String();

    // Continue with the request
    handler.next(options);
  }
}