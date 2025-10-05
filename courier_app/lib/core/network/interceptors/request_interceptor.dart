import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

/// [RequestInterceptor] - Dio interceptor that adds common tracking headers to all HTTP requests
///
/// **What it does:**
/// - Generates unique request ID (UUID v4) for each request
/// - Adds X-Request-ID header for distributed tracing
/// - Adds X-Request-Time header with ISO 8601 timestamp
/// - Enables request correlation across backend services
/// - Simplifies debugging by tracking requests end-to-end
///
/// **Why it exists:**
/// - Request tracking across distributed systems (microservices)
/// - Correlate client requests with backend logs
/// - Debug timing issues (request sent time vs received time)
/// - Track request lifecycle through multiple services
/// - Enable performance monitoring and analysis
/// - Helps reproduce bugs with specific request IDs
///
/// **Request Flow:**
/// ```
/// Client Request
///     ↓
/// RequestInterceptor
///     ↓
/// Generate UUID v4 → Add X-Request-ID header
///     ↓
/// Get current time → Add X-Request-Time header
///     ↓
/// Forward to next interceptor → Backend logs request ID
/// ```
///
/// **Headers Added:**
/// - `X-Request-ID: "550e8400-e29b-41d4-a716-446655440000"` (UUID v4)
/// - `X-Request-Time: "2025-10-04T14:30:00.000Z"` (ISO 8601 format)
///
/// **Backend Benefits:**
/// ```
/// // Backend can log request ID for correlation
/// logger.info("Processing order", { requestId: req.headers['x-request-id'] })
///
/// // Track request through multiple services
/// Service A (x-request-id: abc123) → Service B (same ID) → Service C (same ID)
///
/// // User reports bug: "My order failed"
/// // Find in logs: X-Request-ID from error UI → Backend logs → Root cause
/// ```
///
/// **Usage Example:**
/// ```dart
/// // Create request interceptor
/// final requestInterceptor = RequestInterceptor();
///
/// // Add to Dio interceptor chain (FIRST for request ID generation)
/// final dio = Dio()
///   ..interceptors.addAll([
///     requestInterceptor,      // ← First: Generate request ID
///     authInterceptor,         // ← Then: Add auth tokens
///     csrfInterceptor,         // ← Then: Add CSRF tokens
///     loggingInterceptor,      // ← Last: Log complete request
///   ]);
///
/// // Now every request has tracking headers
/// await dio.get('/users/profile');
/// // Request headers will include:
/// // X-Request-ID: "550e8400-e29b-41d4-a716-446655440000"
/// // X-Request-Time: "2025-10-04T14:30:00.000Z"
/// ```
///
/// **IMPROVEMENT:**
/// - [High Priority] Store request ID in context for error reporting (associate errors with requests)
/// - [Medium Priority] Add request correlation chain (parent request ID for nested calls)
/// - [Medium Priority] Add app version and build number headers (track issues by version)
/// - [Low Priority] Add device/platform headers (OS, device model for debugging)
/// - [Low Priority] Add user ID header for authenticated requests (track by user)
class RequestInterceptor extends Interceptor {
  /// UUID generator for creating unique request IDs
  ///
  /// **Why const:**
  /// - UUID generator is stateless (no mutable state)
  /// - Safe to reuse across requests
  /// - Const reduces memory allocation
  ///
  /// **UUID v4:**
  /// - Random UUID (no timestamp component)
  /// - 128-bit identifier (extremely low collision probability)
  /// - Format: "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
  final _uuid = const Uuid();

  /// Intercepts request and adds tracking headers
  ///
  /// **What it does:**
  /// 1. Generates unique UUID v4 for request
  /// 2. Adds X-Request-ID header with UUID
  /// 3. Captures current timestamp (ISO 8601 format)
  /// 4. Adds X-Request-Time header with timestamp
  /// 5. Forwards request to next interceptor
  ///
  /// **Why these headers:**
  /// - X-Request-ID: Standard distributed tracing header
  /// - X-Request-Time: Helps identify timing issues (client clock vs server clock)
  ///
  /// **Parameters:**
  /// - [options]: Request options (method, path, headers, etc.)
  /// - [handler]: Handler to forward request to next interceptor
  ///
  /// **Example:**
  /// ```dart
  /// // Before RequestInterceptor
  /// Headers: {
  ///   "Content-Type": "application/json"
  /// }
  ///
  /// // After RequestInterceptor
  /// Headers: {
  ///   "Content-Type": "application/json",
  ///   "X-Request-ID": "550e8400-e29b-41d4-a716-446655440000",
  ///   "X-Request-Time": "2025-10-04T14:30:00.000Z"
  /// }
  /// ```
  ///
  /// **IMPROVEMENT:**
  /// - [✅ COMPLETED] Store request ID in extra for error correlation
  /// - [Medium Priority] Add request ID to logs and error reports
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Generate unique request ID
    final requestId = _uuid.v4();
    final requestTime = DateTime.now();

    // Add X-Request-ID header for request tracking
    options.headers['X-Request-ID'] = requestId;

    // Add timestamp header
    options.headers['X-Request-Time'] = requestTime.toIso8601String();

    // Store request ID and time in extra for error correlation
    // This allows error handlers to access the request ID without parsing headers
    options.extra['request_id'] = requestId;
    options.extra['request_time'] = requestTime;

    // Continue with the request
    handler.next(options);
  }
}