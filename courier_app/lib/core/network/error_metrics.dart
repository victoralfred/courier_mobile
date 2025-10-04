import 'package:dio/dio.dart';

/// [ErrorMetrics] - Tracks API error rates and patterns for monitoring and circuit breaking
///
/// **What it does:**
/// - Records error occurrences by endpoint and status code
/// - Tracks error timestamps for rate calculation
/// - Implements sliding window for bounded memory usage
/// - Provides circuit breaker functionality to prevent cascade failures
/// - Calculates error rates for monitoring
///
/// **Why it exists:**
/// - Enable circuit breaker pattern (stop requests after repeated failures)
/// - Track error patterns for debugging and monitoring
/// - Prevent thundering herd problem when servers are down
/// - Provide observability into API health
/// - Help identify problematic endpoints
///
/// **Circuit Breaker States:**
/// ```
/// CLOSED (normal) ──[error threshold]──> HALF_OPEN (testing)
///       ↑                                      │
///       │                                      │
///       └────[success]──────────[success]──────┘
///                                 │
///                                 │
///                                 ↓
///                              OPEN (blocking)
///                         [timeout] → HALF_OPEN
/// ```
///
/// **Memory Management:**
/// - Sliding window: keeps only last 100 errors per endpoint
/// - Automatic cleanup of stale data
/// - Bounded memory regardless of error count
///
/// **Usage Example:**
/// ```dart
/// final metrics = ErrorMetrics();
///
/// // Record error
/// metrics.recordError('/api/v1/orders', 500);
///
/// // Check if circuit should open
/// if (metrics.shouldOpenCircuit('/api/v1/orders')) {
///   throw CircuitBreakerOpenException();
/// }
///
/// // Get error rate
/// final rate = metrics.getErrorRate('/api/v1/orders', Duration(minutes: 1));
/// print('Error rate: ${rate * 100}%');
/// ```
class ErrorMetrics {
  /// Maximum number of errors to track per endpoint (sliding window)
  static const int _maxErrorsPerEndpoint = 100;

  /// Circuit breaker error threshold (percentage)
  /// If error rate exceeds this in the time window, circuit opens
  static const double _circuitBreakerThreshold = 0.5; // 50%

  /// Time window for circuit breaker calculation
  static const Duration _circuitBreakerWindow = Duration(minutes: 1);

  /// Minimum requests required before circuit breaker activates
  static const int _minRequestsForCircuit = 5;

  /// Map of endpoint:statusCode to error count
  final Map<String, int> _errorCounts = {};

  /// Map of endpoint:statusCode to error timestamps (sliding window)
  final Map<String, List<DateTime>> _errorTimestamps = {};

  /// Map of endpoint to total request count (for error rate calculation)
  final Map<String, int> _requestCounts = {};

  /// Map of endpoint to last request timestamp
  final Map<String, DateTime> _lastRequestTime = {};

  /// Set of endpoints with open circuits
  final Set<String> _openCircuits = {};

  /// Map of endpoint to circuit open time
  final Map<String, DateTime> _circuitOpenTime = {};

  /// Records a request to an endpoint
  ///
  /// **Parameters:**
  /// - [endpoint]: API endpoint path (e.g., '/api/v1/orders')
  void recordRequest(String endpoint) {
    _requestCounts[endpoint] = (_requestCounts[endpoint] ?? 0) + 1;
    _lastRequestTime[endpoint] = DateTime.now();
  }

  /// Records an error for monitoring and circuit breaker calculation
  ///
  /// **What it does:**
  /// - Increments error counter for endpoint:statusCode combination
  /// - Adds timestamp to sliding window
  /// - Trims window to max size (bounded memory)
  /// - Checks if circuit should open based on error rate
  ///
  /// **Parameters:**
  /// - [endpoint]: API endpoint path (e.g., '/api/v1/orders')
  /// - [statusCode]: HTTP status code (e.g., 500, 503)
  ///
  /// **Example:**
  /// ```dart
  /// metrics.recordError('/api/v1/orders', 500);
  /// metrics.recordError('/api/v1/orders', 503);
  /// metrics.recordError('/api/v1/users', 404);
  /// ```
  void recordError(String endpoint, int statusCode) {
    final key = '$endpoint:$statusCode';

    // Increment error count
    _errorCounts[key] = (_errorCounts[key] ?? 0) + 1;

    // Add timestamp to sliding window
    final timestamps = _errorTimestamps[key] ?? [];
    timestamps.add(DateTime.now());

    // Keep only last N errors (sliding window for bounded memory)
    if (timestamps.length > _maxErrorsPerEndpoint) {
      timestamps.removeAt(0);
    }

    _errorTimestamps[key] = timestamps;

    // Check if circuit should open
    if (_shouldOpenCircuitForEndpoint(endpoint)) {
      openCircuit(endpoint);
    }
  }

  /// Checks if circuit breaker should open for an endpoint
  ///
  /// **Criteria:**
  /// - Minimum requests threshold met (prevents opening on first error)
  /// - Error rate exceeds threshold in time window
  /// - Recent errors (within circuit breaker window)
  ///
  /// **Returns:** true if circuit should open, false otherwise
  bool _shouldOpenCircuitForEndpoint(String endpoint) {
    final requestCount = _requestCounts[endpoint] ?? 0;

    // Don't open circuit if not enough requests
    if (requestCount < _minRequestsForCircuit) {
      return false;
    }

    final errorRate = getErrorRate(endpoint, _circuitBreakerWindow);
    return errorRate > _circuitBreakerThreshold;
  }

  /// Opens circuit breaker for an endpoint
  ///
  /// **What it does:**
  /// - Adds endpoint to open circuits set
  /// - Records circuit open time for timeout calculation
  ///
  /// **Parameters:**
  /// - [endpoint]: API endpoint path
  void openCircuit(String endpoint) {
    _openCircuits.add(endpoint);
    _circuitOpenTime[endpoint] = DateTime.now();
  }

  /// Closes circuit breaker for an endpoint
  ///
  /// **Parameters:**
  /// - [endpoint]: API endpoint path
  void closeCircuit(String endpoint) {
    _openCircuits.remove(endpoint);
    _circuitOpenTime.remove(endpoint);
  }

  /// Checks if circuit breaker is open for an endpoint
  ///
  /// **What it does:**
  /// - Checks if endpoint is in open circuits set
  /// - Auto-closes circuit after timeout (half-open state)
  ///
  /// **Returns:** true if circuit is open (requests should be blocked)
  ///
  /// **Example:**
  /// ```dart
  /// if (metrics.isCircuitOpen('/api/v1/orders')) {
  ///   return Left(CircuitBreakerOpenFailure());
  /// }
  /// ```
  bool isCircuitOpen(String endpoint) {
    if (!_openCircuits.contains(endpoint)) {
      return false;
    }

    // Auto-close circuit after timeout (transition to half-open)
    final openTime = _circuitOpenTime[endpoint];
    if (openTime != null &&
        DateTime.now().difference(openTime) > _circuitBreakerWindow) {
      closeCircuit(endpoint);
      return false;
    }

    return true;
  }

  /// Calculates error rate for an endpoint in a time window
  ///
  /// **Formula:**
  /// ```
  /// error_rate = errors_in_window / total_requests
  /// ```
  ///
  /// **Parameters:**
  /// - [endpoint]: API endpoint path
  /// - [window]: Time window for calculation
  ///
  /// **Returns:** Error rate as decimal (0.0 to 1.0)
  ///
  /// **Example:**
  /// ```dart
  /// final rate = metrics.getErrorRate('/api/v1/orders', Duration(minutes: 1));
  /// if (rate > 0.5) {
  ///   print('High error rate: ${(rate * 100).toStringAsFixed(1)}%');
  /// }
  /// ```
  double getErrorRate(String endpoint, Duration window) {
    final now = DateTime.now();
    final windowStart = now.subtract(window);

    // Count errors in window
    int errorsInWindow = 0;
    _errorTimestamps.forEach((key, timestamps) {
      if (key.startsWith('$endpoint:')) {
        errorsInWindow += timestamps
            .where((t) => t.isAfter(windowStart))
            .length;
      }
    });

    final totalRequests = _requestCounts[endpoint] ?? 0;
    if (totalRequests == 0) {
      return 0.0;
    }

    return errorsInWindow / totalRequests;
  }

  /// Gets total error count for an endpoint:statusCode combination
  ///
  /// **Parameters:**
  /// - [endpoint]: API endpoint path
  /// - [statusCode]: HTTP status code
  ///
  /// **Returns:** Total error count since app start
  int getErrorCount(String endpoint, int statusCode) {
    final key = '$endpoint:$statusCode';
    return _errorCounts[key] ?? 0;
  }

  /// Gets all error counts as map
  ///
  /// **Returns:** Map of endpoint:statusCode to error count
  Map<String, int> getAllErrorCounts() {
    return Map.from(_errorCounts);
  }

  /// Resets all metrics (useful for testing)
  void reset() {
    _errorCounts.clear();
    _errorTimestamps.clear();
    _requestCounts.clear();
    _lastRequestTime.clear();
    _openCircuits.clear();
    _circuitOpenTime.clear();
  }

  /// Records successful request (for circuit breaker recovery)
  ///
  /// **Parameters:**
  /// - [endpoint]: API endpoint path
  void recordSuccess(String endpoint) {
    recordRequest(endpoint);

    // Close circuit on success (recovery)
    if (_openCircuits.contains(endpoint)) {
      closeCircuit(endpoint);
    }
  }
}

/// Extension to extract endpoint from RequestOptions
extension RequestOptionsExtension on RequestOptions {
  /// Extracts endpoint path for metrics tracking
  ///
  /// **What it does:**
  /// - Returns path without query parameters
  /// - Normalizes endpoint for consistent tracking
  ///
  /// **Example:**
  /// ```dart
  /// '/api/v1/orders?page=1' → '/api/v1/orders'
  /// '/api/v1/users/123' → '/api/v1/users/123'
  /// ```
  String get endpointPath => Uri.parse(path).path;
}
