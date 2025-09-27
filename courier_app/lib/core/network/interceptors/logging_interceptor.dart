import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Interceptor for logging HTTP requests and responses
class LoggingInterceptor extends Interceptor {
  final bool isDebug;

  LoggingInterceptor({required this.isDebug});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (isDebug) {
      _logRequest(options);
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (isDebug) {
      _logResponse(response);
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (isDebug) {
      _logError(err);
    }
    handler.next(err);
  }

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
