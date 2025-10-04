import 'dart:collection';
import 'package:dio/dio.dart';
import '../../services/app_logger.dart';
import '../../../features/auth/domain/services/token_manager.dart';
import '../../error/failures.dart';

/// [AuthRetryInterceptor] - Queues and retries failed requests after token refresh
///
/// **What it does:**
/// - Intercepts 401 Unauthorized errors
/// - Triggers automatic token refresh
/// - Queues concurrent 401 requests
/// - Retries all queued requests after successful refresh
/// - Clears queue and redirects to login on refresh failure
///
/// **Why it exists:**
/// - Seamless token refresh UX (users don't see auth errors)
/// - Prevents duplicate token refresh calls
/// - Handles race conditions when multiple requests fail simultaneously
/// - Improves reliability by automatically recovering from expired tokens
///
/// **Request Flow:**
/// ```
/// Request 1 → 401 → Queue → Trigger refresh
/// Request 2 → 401 → Queue → Wait for refresh
/// Request 3 → 401 → Queue → Wait for refresh
///                             ↓
///                      Token refreshed
///                             ↓
///                   Replay queued requests
///                             ↓
///                   Requests 1,2,3 succeed
/// ```
///
/// **Failure Flow:**
/// ```
/// Request → 401 → Queue → Trigger refresh
///                             ↓
///                      Refresh fails (401)
///                             ↓
///                      Clear queue
///                             ↓
///                      Call onAuthFailure
///                             ↓
///                   Navigate to login
/// ```
///
/// **Usage Example:**
/// ```dart
/// final authRetryInterceptor = AuthRetryInterceptor(
///   tokenManager: tokenManager,
///   onAuthFailure: () async {
///     await tokenManager.clearTokens();
///     navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
///   },
/// );
///
/// dio.interceptors.add(authRetryInterceptor);
///
/// // Requests automatically retry after token refresh
/// await dio.get('/api/v1/profile'); // Auto-retries if 401
/// ```
class AuthRetryInterceptor extends Interceptor {
  /// Logger instance
  final AppLogger _logger = AppLogger.auth();

  /// Token manager for refresh operations
  final TokenManager tokenManager;

  /// Callback when authentication completely fails
  final Future<void> Function()? onAuthFailure;

  /// Maximum queue size to prevent memory issues
  final int maxQueueSize;

  /// Timeout for waiting on token refresh
  final Duration queueTimeout;

  /// Queue of pending requests waiting for token refresh
  final Queue<_PendingRequest> _pendingRequests = Queue();

  /// Flag to track if token refresh is in progress
  bool _isRefreshing = false;

  /// Creates auth retry interceptor
  ///
  /// **Parameters:**
  /// - [tokenManager]: Token manager for refresh operations
  /// - [onAuthFailure]: Callback when auth fails (navigate to login)
  /// - [maxQueueSize]: Max pending requests (default: 50)
  /// - [queueTimeout]: Max wait time for refresh (default: 30s)
  ///
  /// **Example:**
  /// ```dart
  /// AuthRetryInterceptor(
  ///   tokenManager: getIt<TokenManager>(),
  ///   onAuthFailure: () => handleLogout(),
  ///   maxQueueSize: 100,
  /// )
  /// ```
  AuthRetryInterceptor({
    required this.tokenManager,
    this.onAuthFailure,
    this.maxQueueSize = 50,
    this.queueTimeout = const Duration(seconds: 30),
  });

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Only handle 401 errors
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    final requestOptions = err.requestOptions;
    final requestId = requestOptions.extra['request_id'] as String?;

    // Don't retry auth endpoints (prevents infinite loops)
    if (_isAuthEndpoint(requestOptions.path)) {
      _logger.debug('Auth endpoint failed, not retrying', metadata: {
        'request_id': requestId,
        'endpoint': requestOptions.path,
      });
      return handler.next(err);
    }

    // Check queue size limit
    if (_pendingRequests.length >= maxQueueSize) {
      _logger.warning('Request queue full, rejecting request', metadata: {
        'request_id': requestId,
        'queue_size': _pendingRequests.length,
        'max_queue_size': maxQueueSize,
      });
      return handler.next(err);
    }

    _logger.info('Request failed with 401, queueing for retry', metadata: {
      'request_id': requestId,
      'endpoint': requestOptions.path,
      'is_refreshing': _isRefreshing,
      'queue_size': _pendingRequests.length,
    });

    // Create pending request with handler
    final pendingRequest = _PendingRequest(
      requestOptions: requestOptions,
      handler: handler,
      requestId: requestId ?? 'unknown',
    );

    _pendingRequests.add(pendingRequest);

    // If not already refreshing, trigger refresh
    if (!_isRefreshing) {
      await _refreshTokenAndRetry();
    }

    // Request is queued, don't call handler.next() or handler.reject()
    // The handler will be called when refresh completes
  }

  /// Refreshes token and retries all queued requests
  Future<void> _refreshTokenAndRetry() async {
    _isRefreshing = true;

    _logger.info('Starting token refresh', metadata: {
      'queued_requests': _pendingRequests.length,
    });

    try {
      // Refresh token with timeout
      final refreshResult = await tokenManager.refreshToken()
          .timeout(queueTimeout);

      refreshResult.fold(
        (failure) async {
          // Refresh failed - clear queue and notify
          _logger.error('Token refresh failed', error: failure, metadata: {
            'queued_requests': _pendingRequests.length,
          });

          await _clearQueueAndNotifyFailure();

          // Call auth failure callback
          if (onAuthFailure != null) {
            await onAuthFailure!();
          }
        },
        (token) async {
          // Refresh succeeded - retry all queued requests
          _logger.info('Token refresh succeeded, retrying queued requests', metadata: {
            'queued_requests': _pendingRequests.length,
          });

          await _retryQueuedRequests();
        },
      );
    } catch (e, stackTrace) {
      _logger.error('Token refresh error', error: e, stackTrace: stackTrace, metadata: {
        'queued_requests': _pendingRequests.length,
      });

      await _clearQueueAndNotifyFailure();

      if (onAuthFailure != null) {
        await onAuthFailure!();
      }
    } finally {
      _isRefreshing = false;
    }
  }

  /// Retries all queued requests with new token
  Future<void> _retryQueuedRequests() async {
    final requestsToRetry = List<_PendingRequest>.from(_pendingRequests);
    _pendingRequests.clear();

    _logger.debug('Retrying ${requestsToRetry.length} queued requests');

    for (final pending in requestsToRetry) {
      try {
        _logger.debug('Retrying request', metadata: {
          'request_id': pending.requestId,
          'endpoint': pending.requestOptions.path,
        });

        // Retry the request with new token
        final response = await Dio().fetch(pending.requestOptions);

        // Resolve the original request
        pending.handler.resolve(response);

        _logger.debug('Request retry succeeded', metadata: {
          'request_id': pending.requestId,
          'status_code': response.statusCode,
        });
      } on DioException catch (e) {
        _logger.warning('Request retry failed', metadata: {
          'request_id': pending.requestId,
          'status_code': e.response?.statusCode,
          'error_type': e.type.toString(),
        });

        // Reject the original request with the error
        pending.handler.next(e);
      } catch (e, stackTrace) {
        _logger.error('Unexpected error retrying request',
            error: e,
            stackTrace: stackTrace,
            metadata: {
          'request_id': pending.requestId,
        });

        // Reject with original error
        pending.handler.next(
          DioException(
            requestOptions: pending.requestOptions,
            error: e,
          ),
        );
      }
    }
  }

  /// Clears queue and notifies all pending requests of failure
  Future<void> _clearQueueAndNotifyFailure() async {
    final requestsToReject = List<_PendingRequest>.from(_pendingRequests);
    _pendingRequests.clear();

    _logger.debug('Clearing ${requestsToReject.length} queued requests');

    for (final pending in requestsToReject) {
      pending.handler.next(
        DioException(
          requestOptions: pending.requestOptions,
          error: const AuthenticationFailure(
            message: 'Authentication failed - please login again',
            code: 'AUTH_REFRESH_FAILED',
          ),
          response: Response(
            statusCode: 401,
            requestOptions: pending.requestOptions,
          ),
        ),
      );
    }
  }

  /// Checks if endpoint is an auth endpoint (should not retry)
  bool _isAuthEndpoint(String path) {
    final authPaths = [
      '/api/v1/auth/login',
      '/api/v1/auth/register',
      '/api/v1/auth/refresh',
      '/api/v1/auth/logout',
      '/api/v1/auth/oauth/authorize',
      '/api/v1/auth/oauth/token',
    ];

    return authPaths.any((authPath) => path.contains(authPath));
  }

  /// Clears the request queue (useful for logout)
  void clearQueue() {
    _logger.debug('Manually clearing request queue', metadata: {
      'queue_size': _pendingRequests.length,
    });
    _pendingRequests.clear();
    _isRefreshing = false;
  }
}

/// Internal class to hold pending request data
class _PendingRequest {
  final RequestOptions requestOptions;
  final ErrorInterceptorHandler handler;
  final String requestId;

  _PendingRequest({
    required this.requestOptions,
    required this.handler,
    required this.requestId,
  });
}
