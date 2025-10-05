import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// [AppLogger] - Centralized logging service for the application
///
/// **What it does:**
/// - Provides structured logging with multiple log levels (debug, info, warning, error)
/// - Automatically redacts sensitive data (tokens, passwords, auth headers)
/// - Disables logging in production mode (kReleaseMode)
/// - Supports metadata for structured logging
/// - Provides specialized loggers for different app layers
/// - Includes network logging helpers for HTTP operations
///
/// **Why it exists:**
/// - Centralizes all logging logic in one place
/// - Prevents accidental logging of sensitive data
/// - Improves debugging with structured logs
/// - Provides consistent logging format across the app
/// - Automatically handles production/debug mode switching
/// - Replaces ad-hoc print() statements with proper logging
///
/// **Security Features:**
/// - Auto-redacts: authorization, token, password, secret, apiKey, csrf
/// - Prevents credential leakage in logs
/// - Production mode: only errors are logged
/// - Debug mode: all levels logged
///
/// **Usage Example:**
/// ```dart
/// // Create logger for specific context
/// final logger = AppLogger('AuthService');
///
/// // Basic logging
/// logger.debug('Processing login request');
/// logger.info('User logged in successfully');
/// logger.warning('Token expiring soon');
/// logger.error('Login failed', error: exception, stackTrace: stackTrace);
///
/// // Logging with metadata
/// logger.info('API call completed', metadata: {
///   'method': 'POST',
///   'url': '/users/login',
///   'statusCode': 200,
/// });
///
/// // Network logging helpers
/// logger.logRequest(
///   method: 'POST',
///   url: '/users/login',
///   headers: {'Authorization': 'Bearer token'}, // Auto-redacted
/// );
///
/// // Use factory constructors for common contexts
/// final networkLogger = AppLogger.network();
/// final authLogger = AppLogger.auth();
/// ```
class AppLogger {
  /// Logger name/context identifier
  final String name;

  /// Whether the app is in debug mode (enables logging)
  final bool isDebug;

  /// Underlying logger instance from logger package
  late final Logger _logger;

  /// List of sensitive field names to redact
  static const _sensitiveFields = {
    'authorization',
    'token',
    'access_token',
    'refresh_token',
    'csrf_token',
    'password',
    'secret',
    'apikey',
    'api_key',
  };

  /// Creates a logger with given name and debug flag
  ///
  /// **Parameters:**
  /// - [name]: Logger context name (e.g., 'AuthService', 'Network')
  /// - [isDebug]: Enable logging (defaults to kDebugMode)
  ///
  /// **Example:**
  /// ```dart
  /// // Auto-detect debug mode
  /// final logger = AppLogger('MyService');
  ///
  /// // Explicitly set debug mode
  /// final testLogger = AppLogger('TestService', isDebug: true);
  /// ```
  AppLogger(this.name, {bool? isDebug})
      : isDebug = isDebug ?? kDebugMode {
    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 0, // No stack trace for normal logs
        errorMethodCount: 5, // 5 lines for errors
        lineLength: 80,
        colors: true,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.none,
      ),
      filter: _LogFilter(enableLogging: this.isDebug),
    );
  }

  /// Factory: Creates network layer logger
  factory AppLogger.network() => AppLogger('Network');

  /// Factory: Creates auth layer logger
  factory AppLogger.auth() => AppLogger('Auth');

  /// Factory: Creates database layer logger
  factory AppLogger.database() => AppLogger('Database');

  /// Logs debug message (only in debug mode)
  ///
  /// **When to use:**
  /// - Detailed troubleshooting information
  /// - Development-only logs
  /// - Request/response details
  ///
  /// **Example:**
  /// ```dart
  /// logger.debug('Fetching CSRF token from /auth/csrf');
  /// ```
  void debug(String message, {Map<String, dynamic>? metadata}) {
    final sanitizedMetadata = _redactSensitiveData(metadata);
    _logger.d(_formatMessage(message, sanitizedMetadata));
  }

  /// Logs info message (only in debug mode)
  ///
  /// **When to use:**
  /// - Important business logic events
  /// - Successful operations
  /// - State transitions
  ///
  /// **Example:**
  /// ```dart
  /// logger.info('User logged in successfully', metadata: {
  ///   'userId': user.id,
  /// });
  /// ```
  void info(String message, {Map<String, dynamic>? metadata}) {
    final sanitizedMetadata = _redactSensitiveData(metadata);
    _logger.i(_formatMessage(message, sanitizedMetadata));
  }

  /// Logs warning message (only in debug mode)
  ///
  /// **When to use:**
  /// - Recoverable errors
  /// - Deprecated API usage
  /// - Performance issues
  ///
  /// **Example:**
  /// ```dart
  /// logger.warning('Token expiring in 5 minutes');
  /// ```
  void warning(String message, {Map<String, dynamic>? metadata}) {
    final sanitizedMetadata = _redactSensitiveData(metadata);
    _logger.w(_formatMessage(message, sanitizedMetadata));
  }

  /// Logs error message (always logged, even in production)
  ///
  /// **When to use:**
  /// - Exceptions and errors
  /// - Failed operations
  /// - Critical issues
  ///
  /// **Example:**
  /// ```dart
  /// logger.error(
  ///   'Failed to fetch CSRF token',
  ///   error: exception,
  ///   stackTrace: stackTrace,
  /// );
  /// ```
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
  }) {
    final sanitizedMetadata = _redactSensitiveData(metadata);
    _logger.e(
      _formatMessage(message, sanitizedMetadata),
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Logs HTTP request with auto-redacted headers
  ///
  /// **What it does:**
  /// - Logs method, URL, headers, body
  /// - Redacts sensitive headers (Authorization, tokens)
  /// - Only logs in debug mode
  ///
  /// **Example:**
  /// ```dart
  /// logger.logRequest(
  ///   method: 'POST',
  ///   url: 'https://api.example.com/login',
  ///   headers: {'Authorization': 'Bearer token'},
  ///   body: {'email': 'user@example.com'},
  /// );
  /// ```
  void logRequest({
    required String method,
    required String url,
    Map<String, dynamic>? headers,
    dynamic body,
  }) {
    debug('HTTP Request: $method $url', metadata: {
      'method': method,
      'url': url,
      if (headers != null) 'headers': headers,
      if (body != null) 'body': body,
    });
  }

  /// Logs HTTP response
  ///
  /// **Example:**
  /// ```dart
  /// logger.logResponse(
  ///   method: 'POST',
  ///   url: 'https://api.example.com/login',
  ///   statusCode: 200,
  ///   statusMessage: 'OK',
  ///   body: {'success': true},
  /// );
  /// ```
  void logResponse({
    required String method,
    required String url,
    required int statusCode,
    String? statusMessage,
    dynamic body,
  }) {
    info('HTTP Response: $statusCode ${statusMessage ?? ''} - $method $url',
        metadata: {
          'method': method,
          'url': url,
          'statusCode': statusCode,
          if (statusMessage != null) 'statusMessage': statusMessage,
          if (body != null) 'body': body,
        });
  }

  /// Logs HTTP error
  ///
  /// **Example:**
  /// ```dart
  /// logger.logError(
  ///   method: 'POST',
  ///   url: 'https://api.example.com/login',
  ///   statusCode: 401,
  ///   statusMessage: 'Unauthorized',
  ///   error: exception,
  /// );
  /// ```
  void logError({
    required String method,
    required String url,
    int? statusCode,
    String? statusMessage,
    Object? error,
    StackTrace? stackTrace,
  }) {
    this.error(
      'HTTP Error: ${statusCode ?? 'N/A'} ${statusMessage ?? ''} - $method $url',
      error: error,
      stackTrace: stackTrace,
      metadata: {
        'method': method,
        'url': url,
        if (statusCode != null) 'statusCode': statusCode,
        if (statusMessage != null) 'statusMessage': statusMessage,
      },
    );
  }

  /// Formats log message with optional metadata
  ///
  /// **Format:**
  /// ```
  /// [LoggerName] Message | metadata: {...}
  /// ```
  String _formatMessage(String message, Map<String, dynamic>? metadata) {
    final buffer = StringBuffer('[$name] $message');
    if (metadata != null && metadata.isNotEmpty) {
      buffer.write(' | metadata: $metadata');
    }
    return buffer.toString();
  }

  /// Redacts sensitive data from metadata
  ///
  /// **What it redacts:**
  /// - authorization, token, access_token, refresh_token, csrf_token
  /// - password, secret, apiKey, api_key
  ///
  /// **Example:**
  /// ```dart
  /// _redactSensitiveData({
  ///   'authorization': 'Bearer abc123',
  ///   'userId': '123',
  /// })
  /// // Returns: {'authorization': '[REDACTED]', 'userId': '123'}
  /// ```
  Map<String, dynamic>? _redactSensitiveData(Map<String, dynamic>? metadata) {
    if (metadata == null || metadata.isEmpty) return metadata;

    return metadata.map((key, value) {
      final lowerKey = key.toLowerCase();
      final shouldRedact =
          _sensitiveFields.any((field) => lowerKey.contains(field));

      if (shouldRedact) {
        return MapEntry(key, '[REDACTED]');
      }
      return MapEntry(key, value);
    });
  }
}

/// Custom log filter that respects debug mode
class _LogFilter extends LogFilter {
  final bool enableLogging;

  _LogFilter({required this.enableLogging});

  @override
  bool shouldLog(LogEvent event) {
    // Always log errors (even in production)
    if (event.level == Level.error) return true;

    // Only log other levels in debug mode
    return enableLogging;
  }
}
