import 'package:dio/dio.dart';
import '../../services/app_logger.dart';
import '../connectivity_service.dart';
import '../offline_request_queue.dart';

/// [OfflineRequestInterceptor] - Intercepts requests when offline and queues them
///
/// **What it does:**
/// - Detects when device is offline
/// - Queues write operations (POST, PUT, PATCH, DELETE) for later
/// - Returns cached response or error for read operations (GET)
/// - Automatically processes queue when connectivity restored
///
/// **Why it exists:**
/// - Enable offline-first architecture
/// - Prevent data loss during network outages
/// - Improve user experience with seamless offline support
///
/// **Request Flow:**
/// ```
/// Request initiated
///     ↓
/// Check connectivity
///     ↓
/// Online? ────> YES ────> Pass through
///     │
///     NO
///     ↓
/// Write operation? ────> YES ────> Queue request
///     │                              Return success
///     NO
///     ↓
/// Return cached data or error
/// ```
///
/// **Usage Example:**
/// ```dart
/// final interceptor = OfflineRequestInterceptor(
///   connectivityService: connectivityService,
///   offlineQueue: offlineQueue,
/// );
///
/// dio.interceptors.add(interceptor);
///
/// // Requests automatically queued when offline
/// await dio.post('/api/v1/orders', data: orderData);
/// // Returns success immediately, queued for sync
/// ```
class OfflineRequestInterceptor extends Interceptor {
  final AppLogger _logger = AppLogger.network();
  final ConnectivityService connectivityService;
  final OfflineRequestQueue offlineQueue;

  /// Whether to queue write operations when offline
  final bool queueWriteOperations;

  /// HTTP methods considered as write operations
  static const List<String> _writeMethods = ['POST', 'PUT', 'PATCH', 'DELETE'];

  OfflineRequestInterceptor({
    required this.connectivityService,
    required this.offlineQueue,
    this.queueWriteOperations = true,
  });

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final requestId = options.extra['request_id'] as String?;
    final isOnline = await connectivityService.isOnline();

    if (isOnline) {
      // Online - pass through
      return handler.next(options);
    }

    _logger.info('Device offline, handling request', metadata: {
      'request_id': requestId,
      'method': options.method,
      'path': options.path,
    });

    // Check if this is a write operation
    final isWriteOperation =
        _writeMethods.contains(options.method.toUpperCase());

    if (isWriteOperation && queueWriteOperations) {
      // Queue write operation
      await _queueRequest(options, handler);
    } else {
      // Reject read operation with offline error
      _rejectWithOfflineError(options, handler);
    }
  }

  /// Queues a write request for later processing
  Future<void> _queueRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      // Determine priority from request options
      final priority = _determinePriority(options);

      // Enqueue request
      final queueId = await offlineQueue.enqueue(
        requestOptions: options,
        priority: priority,
      );

      _logger.info('Request queued for offline sync', metadata: {
        'request_id': options.extra['request_id'],
        'queue_id': queueId,
        'priority': priority.name,
      });

      // Return success response (request queued)
      handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 202, // Accepted
          data: {
            'success': true,
            'message': 'Request queued for sync',
            'queueId': queueId,
            'offline': true,
          },
        ),
      );
    } catch (e, stackTrace) {
      _logger.error('Failed to queue request',
          error: e, stackTrace: stackTrace, metadata: {
        'request_id': options.extra['request_id'],
      });

      // Reject with queue error
      handler.reject(
        DioException(
          requestOptions: options,
          error: e,
          type: DioExceptionType.unknown,
        ),
      );
    }
  }

  /// Rejects request with offline error
  void _rejectWithOfflineError(
      RequestOptions options, RequestInterceptorHandler handler) {
    _logger.debug('Rejecting read request while offline', metadata: {
      'request_id': options.extra['request_id'],
      'method': options.method,
      'path': options.path,
    });

    handler.reject(
      DioException(
        requestOptions: options,
        error: 'No internet connection',
        type: DioExceptionType.connectionError,
        response: Response(
          requestOptions: options,
          statusCode: 0,
          data: {
            'success': false,
            'error': {
              'code': 'OFFLINE',
              'message':
                  'No internet connection. Please check your network settings.',
            },
          },
        ),
      ),
    );
  }

  /// Determines request priority based on path and data
  RequestPriority _determinePriority(RequestOptions options) {
    final path = options.path.toLowerCase();

    // High: Location updates, Order status (check before /orders)
    if (path.contains('/location') || path.contains('/status')) {
      return RequestPriority.high;
    }

    // Critical: Orders, Payments
    if (path.contains('/orders') || path.contains('/payments')) {
      return RequestPriority.critical;
    }

    // Low: Analytics, Logs
    if (path.contains('/analytics') || path.contains('/logs')) {
      return RequestPriority.low;
    }

    // Normal: Everything else
    return RequestPriority.normal;
  }
}

/// Extension to mark requests as non-queueable
extension OfflineRequestExtension on RequestOptions {
  /// Marks request to bypass offline queue
  ///
  /// **Usage:**
  /// ```dart
  /// final options = RequestOptions(path: '/health')
  ///   ..bypassOfflineQueue();
  /// ```
  void bypassOfflineQueue() {
    extra['bypass_offline_queue'] = true;
  }

  /// Checks if request should bypass offline queue
  bool get shouldBypassOfflineQueue =>
      extra['bypass_offline_queue'] == true;
}
