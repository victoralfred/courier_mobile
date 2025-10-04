import 'dart:math';
import 'package:dio/dio.dart';
import '../../services/app_logger.dart';
import '../connectivity_service.dart';
import '../error_metrics.dart';

/// [RetryInterceptor] - Automatically retries failed requests with exponential backoff
///
/// **What it does:**
/// - Retries failed HTTP requests automatically
/// - Uses exponential backoff to prevent server overload
/// - Adds jitter to prevent thundering herd problem
/// - Only retries safe/idempotent operations
/// - Respects server's Retry-After header
/// - Checks connectivity before retry
/// - Integrates with circuit breaker
///
/// **Why it exists:**
/// - Improve reliability for transient network failures
/// - Reduce user-facing errors from temporary server issues
/// - Prevent cascade failures with intelligent backoff
/// - Handle rate limiting gracefully
///
/// **Retry Strategy:**
/// ```
/// Request fails
///     ↓
/// Is retryable? (GET, PUT, DELETE, 5xx)
///     ↓ YES
/// Circuit open?
///     ↓ NO
/// Has retries left?
///     ↓ YES
/// Calculate delay = baseDelay * (multiplier ^ attempt) + jitter
///     ↓
/// Wait for delay
///     ↓
/// Check connectivity
///     ↓
/// Retry request
/// ```
///
/// **Retryable Conditions:**
/// - HTTP Methods: GET, PUT, DELETE, HEAD (idempotent)
/// - Status Codes: 408 (timeout), 429 (rate limit), 500, 502, 503, 504
/// - Network Errors: timeout, connection errors
///
/// **Non-Retryable:**
/// - POST requests (not idempotent unless explicitly marked)
/// - 4xx client errors (except 408, 429)
/// - Circuit breaker open
/// - No connectivity
///
/// **Usage Example:**
/// ```dart
/// final retryInterceptor = RetryInterceptor(
///   maxRetries: 3,
///   baseDelay: Duration(milliseconds: 500),
///   connectivityService: connectivityService,
/// );
///
/// dio.interceptors.add(retryInterceptor);
///
/// // Request automatically retries on failure
/// await dio.get('/api/v1/orders'); // May retry up to 3 times
/// ```
class RetryInterceptor extends Interceptor {
  /// Logger instance
  final AppLogger _logger = AppLogger.network();

  /// Maximum number of retry attempts
  final int maxRetries;

  /// Base delay for exponential backoff
  final Duration baseDelay;

  /// Multiplier for exponential backoff (delay *= multiplier ^ attempt)
  final double multiplier;

  /// Maximum delay between retries (cap for exponential growth)
  final Duration maxDelay;

  /// Connectivity service to check network status
  final ConnectivityService? connectivityService;

  /// Error metrics for circuit breaker integration
  final ErrorMetrics? errorMetrics;

  /// HTTP status codes that should trigger retry
  static const List<int> _retryableStatusCodes = [
    408, // Request Timeout
    429, // Too Many Requests (rate limiting)
    500, // Internal Server Error
    502, // Bad Gateway
    503, // Service Unavailable
    504, // Gateway Timeout
  ];

  /// HTTP methods that are safe to retry (idempotent)
  static const List<String> _retryableMethods = [
    'GET',
    'HEAD',
    'PUT',
    'DELETE',
    'OPTIONS',
    'TRACE',
  ];

  /// Creates retry interceptor
  ///
  /// **Parameters:**
  /// - [maxRetries]: Maximum retry attempts (default: 3)
  /// - [baseDelay]: Base delay for backoff (default: 500ms)
  /// - [multiplier]: Backoff multiplier (default: 2.0)
  /// - [maxDelay]: Maximum delay cap (default: 10 seconds)
  /// - [connectivityService]: Optional connectivity checker
  /// - [errorMetrics]: Optional metrics tracker
  ///
  /// **Example:**
  /// ```dart
  /// RetryInterceptor(
  ///   maxRetries: 5,
  ///   baseDelay: Duration(seconds: 1),
  ///   multiplier: 1.5,
  /// )
  /// ```
  RetryInterceptor({
    this.maxRetries = 3,
    this.baseDelay = const Duration(milliseconds: 500),
    this.multiplier = 2.0,
    this.maxDelay = const Duration(seconds: 10),
    this.connectivityService,
    this.errorMetrics,
  });

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final requestOptions = err.requestOptions;
    final retryCount = requestOptions.extra['retry_count'] as int? ?? 0;

    // Check if request should be retried
    if (!_shouldRetry(err, retryCount)) {
      _logger.debug('Request not retryable', metadata: {
        'request_id': requestOptions.extra['request_id'],
        'endpoint': requestOptions.endpointPath,
        'retry_count': retryCount,
        'reason': _getNoRetryReason(err, retryCount),
      });
      return handler.next(err);
    }

    // Check circuit breaker
    final endpoint = requestOptions.endpointPath;
    if (errorMetrics?.isCircuitOpen(endpoint) == true) {
      _logger.warning('Circuit breaker open, skipping retry', metadata: {
        'request_id': requestOptions.extra['request_id'],
        'endpoint': endpoint,
      });
      return handler.next(err);
    }

    // Check connectivity
    if (connectivityService != null) {
      final isConnected = await connectivityService!.isOnline();
      if (!isConnected) {
        _logger.warning('No connectivity, skipping retry', metadata: {
          'request_id': requestOptions.extra['request_id'],
          'endpoint': endpoint,
        });
        return handler.next(err);
      }
    }

    // Calculate retry delay with exponential backoff + jitter
    final delay = _calculateDelay(retryCount, err.response);

    _logger.info('Retrying request', metadata: {
      'request_id': requestOptions.extra['request_id'],
      'endpoint': endpoint,
      'retry_count': retryCount + 1,
      'max_retries': maxRetries,
      'delay_ms': delay.inMilliseconds,
      'status_code': err.response?.statusCode,
    });

    // Wait before retry
    await Future.delayed(delay);

    // Update retry count
    requestOptions.extra['retry_count'] = retryCount + 1;

    // Retry the request
    try {
      final response = await Dio().fetch(requestOptions);
      return handler.resolve(response);
    } on DioException catch (e) {
      // Retry failed, pass to next error handler
      return handler.next(e);
    }
  }

  /// Determines if request should be retried
  ///
  /// **Criteria:**
  /// - Retry count < max retries
  /// - Request method is idempotent
  /// - Error is transient (network, timeout, 5xx)
  ///
  /// **Returns:** true if should retry
  bool _shouldRetry(DioException err, int retryCount) {
    // Check retry limit
    if (retryCount >= maxRetries) {
      return false;
    }

    // Check if method is retryable
    if (!_retryableMethods.contains(err.requestOptions.method.toUpperCase())) {
      // Allow POST if explicitly marked retryable
      if (err.requestOptions.extra['retryable'] != true) {
        return false;
      }
    }

    // Check error type
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true; // Network errors are retryable

      case DioExceptionType.badResponse:
        // Check if status code is retryable
        final statusCode = err.response?.statusCode;
        return statusCode != null && _retryableStatusCodes.contains(statusCode);

      case DioExceptionType.cancel:
        return false; // User cancelled, don't retry

      case DioExceptionType.unknown:
      default:
        return false; // Unknown errors, don't retry
    }
  }

  /// Calculates retry delay with exponential backoff and jitter
  ///
  /// **Formula:**
  /// ```
  /// delay = min(baseDelay * (multiplier ^ attempt), maxDelay) + jitter
  /// jitter = random(0, delay * 0.1)  // 10% jitter
  /// ```
  ///
  /// **Why jitter:**
  /// - Prevents thundering herd when many clients retry simultaneously
  /// - Spreads out retries over time
  ///
  /// **Respects Retry-After:**
  /// - Uses server's Retry-After header if present
  ///
  /// **Parameters:**
  /// - [attempt]: Current retry attempt number (0-indexed)
  /// - [response]: HTTP response (may contain Retry-After header)
  ///
  /// **Returns:** Delay duration
  Duration _calculateDelay(int attempt, Response? response) {
    // Check for Retry-After header
    if (response != null) {
      final retryAfter = response.headers.value('retry-after');
      if (retryAfter != null) {
        final seconds = int.tryParse(retryAfter);
        if (seconds != null) {
          return Duration(seconds: seconds);
        }
      }
    }

    // Calculate exponential backoff
    final delayMs = baseDelay.inMilliseconds * pow(multiplier, attempt);
    final cappedDelay = Duration(milliseconds: delayMs.toInt())
        .clamp(baseDelay, maxDelay);

    // Add jitter (10% of delay)
    final jitterMs = Random().nextInt((cappedDelay.inMilliseconds * 0.1).toInt());

    return cappedDelay + Duration(milliseconds: jitterMs);
  }

  /// Gets reason why request is not retryable (for logging)
  String _getNoRetryReason(DioException err, int retryCount) {
    if (retryCount >= maxRetries) {
      return 'max_retries_exceeded';
    }

    if (!_retryableMethods.contains(err.requestOptions.method.toUpperCase())) {
      if (err.requestOptions.extra['retryable'] != true) {
        return 'method_not_idempotent';
      }
    }

    if (err.type == DioExceptionType.cancel) {
      return 'request_cancelled';
    }

    if (err.type == DioExceptionType.badResponse) {
      final statusCode = err.response?.statusCode;
      if (statusCode != null && !_retryableStatusCodes.contains(statusCode)) {
        return 'status_code_not_retryable';
      }
    }

    return 'unknown';
  }
}

/// Extension methods for retry configuration
extension RetryableRequest on RequestOptions {
  /// Marks request as explicitly retryable (even if POST)
  ///
  /// **Usage:**
  /// ```dart
  /// final options = RequestOptions(path: '/api/v1/orders')
  ///   ..markRetryable();
  ///
  /// await dio.fetch(options);
  /// ```
  void markRetryable() {
    extra['retryable'] = true;
  }

  /// Marks request as non-retryable
  void markNonRetryable() {
    extra['retryable'] = false;
  }
}

/// Extension to clamp duration
extension DurationClamp on Duration {
  /// Clamps duration between min and max
  Duration clamp(Duration min, Duration max) {
    if (this < min) return min;
    if (this > max) return max;
    return this;
  }
}
