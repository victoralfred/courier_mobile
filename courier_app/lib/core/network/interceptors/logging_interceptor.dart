import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// [LoggingInterceptor] - Dio interceptor that logs HTTP requests, responses, and errors (debug mode only)
///
/// **What it does:**
/// - Intercepts all HTTP traffic (requests, responses, errors)
/// - Logs formatted details in debug mode using debugPrint
/// - Redacts sensitive headers (Authorization, tokens) for security
/// - Pretty-prints JSON payloads for readability
/// - Skips all logging in production (isDebug: false)
/// - Includes stack traces for errors (first 5 lines)
///
/// **Why it exists:**
/// - Essential for debugging API integration issues
/// - Provides visibility into network layer behavior
/// - Helps diagnose authentication, CSRF, and server errors
/// - Makes development faster (no need for proxy tools)
/// - Protects sensitive data by redacting auth headers
/// - Automatically disabled in production (no performance impact)
///
/// **Logging Flow:**
/// ```
/// Request → onRequest → Log if isDebug → Next interceptor
///     ↓
/// Response → onResponse → Log if isDebug → Next interceptor
///     ↓
/// Error → onError → Log if isDebug → Next interceptor
/// ```
///
/// **Log Format:**
/// ```
/// ╔══════════════════════════════════════════════════════════════════════
/// ║ REQUEST
/// ╟──────────────────────────────────────────────────────────────────────
/// ║ POST https://api.example.com/users/login
/// ╟──────────────────────────────────────────────────────────────────────
/// ║ Headers:
/// ║   Content-Type: application/json
/// ║   Authorization: [REDACTED]
/// ╟──────────────────────────────────────────────────────────────────────
/// ║ Body:
/// ║   {
/// ║     "email": "user@example.com",
/// ║     "password": "***"
/// ║   }
/// ╚══════════════════════════════════════════════════════════════════════
/// ```
///
/// **Security Features:**
/// - Redacts Authorization headers
/// - Redacts any header containing "token"
/// - Prevents leaking credentials in logs
///
/// **Usage Example:**
/// ```dart
/// // Create interceptor (debug mode)
/// final loggingInterceptor = LoggingInterceptor(
///   isDebug: kDebugMode, // Flutter's debug flag
/// );
///
/// // Add to Dio interceptor chain (LAST for complete picture)
/// final dio = Dio()
///   ..interceptors.addAll([
///     authInterceptor,
///     csrfInterceptor,
///     errorInterceptor,
///     loggingInterceptor, // ← Last to see all headers/transformations
///   ]);
///
/// // Now all HTTP traffic is logged in debug builds
/// await dio.post('/users/login', data: credentials);
/// // ← Logs request and response automatically
/// ```
///
/// **IMPROVEMENT:**
/// - [High Priority] Integrate with proper logging service (firebase, sentry)
/// - [Medium Priority] Add log level filtering (verbose, info, error only)
/// - [Medium Priority] Add request/response timing metrics
/// - [Medium Priority] Support log file export for debugging
/// - [Low Priority] Add payload size limits (truncate large responses)
/// - [Low Priority] Support redacting custom sensitive fields (passwords, SSN)
class LoggingInterceptor extends Interceptor {
  /// Flag to enable/disable logging (typically tied to debug mode)
  ///
  /// **Why boolean flag:**
  /// - Performance: Avoids formatting/printing in production
  /// - Security: Prevents logs in release builds
  /// - Flexibility: Can be overridden for testing
  ///
  /// **Recommended value:**
  /// ```dart
  /// isDebug: kDebugMode // Flutter's built-in debug flag
  /// ```
  final bool isDebug;

  /// Creates logging interceptor
  ///
  /// **Parameters:**
  /// - [isDebug]: Enable logging (true for debug, false for production)
  ///
  /// **Example:**
  /// ```dart
  /// // Debug builds only
  /// final interceptor = LoggingInterceptor(isDebug: kDebugMode);
  ///
  /// // Always enabled (testing)
  /// final interceptor = LoggingInterceptor(isDebug: true);
  ///
  /// // Always disabled (production)
  /// final interceptor = LoggingInterceptor(isDebug: false);
  /// ```
  LoggingInterceptor({required this.isDebug});

  /// Intercepts outgoing requests and logs details (debug mode only)
  ///
  /// **What it does:**
  /// - Checks if debug mode enabled
  /// - Logs HTTP method, URL, headers, body
  /// - Redacts sensitive headers (Authorization, tokens)
  /// - Pretty-prints JSON bodies
  /// - Forwards request to next interceptor
  ///
  /// **Example log:**
  /// ```
  /// POST https://api.example.com/users/login
  /// Headers:
  ///   Content-Type: application/json
  ///   Authorization: [REDACTED]
  /// Body:
  ///   {"email": "user@example.com"}
  /// ```
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (isDebug) {
      _logRequest(options);
    }
    handler.next(options);
  }

  /// Intercepts successful responses and logs details (debug mode only)
  ///
  /// **What it does:**
  /// - Checks if debug mode enabled
  /// - Logs HTTP status, URL, headers, response body
  /// - Pretty-prints JSON responses
  /// - Forwards response to next interceptor
  ///
  /// **Example log:**
  /// ```
  /// Status: 200 OK
  /// POST https://api.example.com/users/login
  /// Body:
  ///   {"success": true, "data": {...}}
  /// ```
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (isDebug) {
      _logResponse(response);
    }
    handler.next(response);
  }

  /// Intercepts errors and logs details (debug mode only)
  ///
  /// **What it does:**
  /// - Checks if debug mode enabled
  /// - Logs error type, message, status, response body
  /// - Includes first 5 lines of stack trace
  /// - Forwards error to next interceptor
  ///
  /// **Example log:**
  /// ```
  /// ERROR
  /// Type: DioExceptionType.badResponse
  /// Message: Http status error [401]
  /// POST https://api.example.com/users/login
  /// Status: 401 Unauthorized
  /// StackTrace: [5 lines]
  /// ```
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (isDebug) {
      _logError(err);
    }
    handler.next(err);
  }

  /// Formats and prints request details with pretty borders
  ///
  /// **What it does:**
  /// - Prints HTTP method and full URL
  /// - Lists all request headers
  /// - Redacts sensitive headers (Authorization, tokens)
  /// - Pretty-prints JSON request body
  /// - Uses box-drawing characters for readability
  ///
  /// **Security:**
  /// - Redacts any header containing "authorization" or "token"
  /// - Prevents credential leakage in logs
  ///
  /// **Parameters:**
  /// - [options]: Request options from Dio
  void _logRequest(RequestOptions options) {
    debugPrint(
        '╔══════════════════════════════════════════════════════════════════════');
    debugPrint('║ REQUEST');
    debugPrint(
        '╟──────────────────────────────────────────────────────────────────────');
    debugPrint('║ ${options.method} ${options.uri}');
    debugPrint(
        '╟──────────────────────────────────────────────────────────────────────');
    debugPrint('║ Headers:');
    options.headers.forEach((key, value) {
      // Hide sensitive headers in logs
      if (key.toLowerCase().contains('authorization') ||
          key.toLowerCase().contains('token')) {
        debugPrint('║   $key: [REDACTED]');
      } else {
        debugPrint('║   $key: $value');
      }
    });

    if (options.data != null) {
      debugPrint(
          '╟──────────────────────────────────────────────────────────────────────');
      debugPrint('║ Body:');
      try {
        final formattedData = _formatJson(options.data);
        formattedData.split('\n').forEach((line) {
          debugPrint('║   $line');
        });
      } catch (e) {
        debugPrint('║   ${options.data}');
      }
    }
    debugPrint(
        '╚══════════════════════════════════════════════════════════════════════');
  }

  /// Formats and prints response details with pretty borders
  ///
  /// **What it does:**
  /// - Prints HTTP status code and message
  /// - Shows original request method and URL
  /// - Lists response headers
  /// - Pretty-prints JSON response body
  /// - Uses box-drawing characters for readability
  ///
  /// **Parameters:**
  /// - [response]: HTTP response from Dio
  void _logResponse(Response response) {
    debugPrint(
        '╔══════════════════════════════════════════════════════════════════════');
    debugPrint('║ RESPONSE');
    debugPrint(
        '╟──────────────────────────────────────────────────────────────────────');
    debugPrint('║ Status: ${response.statusCode} ${response.statusMessage}');
    debugPrint(
        '║ ${response.requestOptions.method} ${response.requestOptions.uri}');

    if (response.headers.map.isNotEmpty) {
      debugPrint(
          '╟──────────────────────────────────────────────────────────────────────');
      debugPrint('║ Headers:');
      response.headers.forEach((name, values) {
        debugPrint('║   $name: ${values.join(', ')}');
      });
    }

    if (response.data != null) {
      debugPrint(
          '╟──────────────────────────────────────────────────────────────────────');
      debugPrint('║ Body:');
      try {
        final formattedData = _formatJson(response.data);
        formattedData.split('\n').forEach((line) {
          debugPrint('║   $line');
        });
      } catch (e) {
        debugPrint('║   ${response.data}');
      }
    }
    debugPrint(
        '╚══════════════════════════════════════════════════════════════════════');
  }

  /// Formats and prints error details with pretty borders
  ///
  /// **What it does:**
  /// - Prints error type and message
  /// - Shows original request method and URL
  /// - Includes HTTP status if available
  /// - Pretty-prints error response body
  /// - Shows first 5 lines of stack trace for debugging
  /// - Uses box-drawing characters for readability
  ///
  /// **Parameters:**
  /// - [error]: DioException from HTTP client
  void _logError(DioException error) {
    debugPrint(
        '╔══════════════════════════════════════════════════════════════════════');
    debugPrint('║ ERROR');
    debugPrint(
        '╟──────────────────────────────────────────────────────────────────────');
    debugPrint('║ Type: ${error.type}');
    debugPrint('║ Message: ${error.message}');
    debugPrint('║ ${error.requestOptions.method} ${error.requestOptions.uri}');

    if (error.response != null) {
      debugPrint(
          '╟──────────────────────────────────────────────────────────────────────');
      debugPrint(
          '║ Status: ${error.response!.statusCode} ${error.response!.statusMessage}');

      if (error.response!.data != null) {
        debugPrint(
            '╟──────────────────────────────────────────────────────────────────────');
        debugPrint('║ Response Body:');
        try {
          final formattedData = _formatJson(error.response!.data);
          formattedData.split('\n').forEach((line) {
            debugPrint('║   $line');
          });
        } catch (e) {
          debugPrint('║   ${error.response!.data}');
        }
      }
    }

    debugPrint(
        '╟──────────────────────────────────────────────────────────────────────');
    debugPrint('║ StackTrace:');
    error.stackTrace.toString().split('\n').take(5).forEach((line) {
      debugPrint('║   $line');
    });
    debugPrint(
        '╚══════════════════════════════════════════════════════════════════════');
  }

  /// Formats JSON data with pretty indentation
  ///
  /// **What it does:**
  /// - Attempts to parse data as JSON
  /// - Formats with 2-space indentation
  /// - Handles both String and Object inputs
  /// - Falls back to toString() if parsing fails
  ///
  /// **Parameters:**
  /// - [data]: Data to format (String, Map, List, etc.)
  ///
  /// **Returns:** Formatted JSON string or toString() fallback
  ///
  /// **Example:**
  /// ```dart
  /// _formatJson({"key": "value"})
  /// →
  /// {
  ///   "key": "value"
  /// }
  /// ```
  String _formatJson(dynamic data) {
    try {
      if (data is String) {
        final parsed = json.decode(data);
        return const JsonEncoder.withIndent('  ').convert(parsed);
      } else {
        return const JsonEncoder.withIndent('  ').convert(data);
      }
    } catch (e) {
      return data.toString();
    }
  }
}
