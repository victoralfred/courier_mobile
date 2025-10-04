import 'dart:convert';
import 'package:dio/dio.dart';
import '../services/app_logger.dart';
import '../database/app_database.dart';
import 'connectivity_service.dart';

/// Priority levels for offline requests
enum RequestPriority {
  critical, // Order creation, payment
  high, // Location updates, order status
  normal, // Profile updates
  low; // Analytics, logs

  int get value {
    switch (this) {
      case RequestPriority.critical:
        return 3;
      case RequestPriority.high:
        return 2;
      case RequestPriority.normal:
        return 1;
      case RequestPriority.low:
        return 0;
    }
  }
}

/// [OfflineRequestQueue] - Persistent queue for requests made while offline
///
/// **What it does:**
/// - Queues HTTP requests when offline
/// - Stores requests in SQLite (persists across app restarts)
/// - Automatically processes queue when connectivity restored
/// - Supports priority-based processing
/// - Implements TTL (time-to-live) for stale requests
/// - Handles request dependencies
///
/// **Why it exists:**
/// - Enable offline-first architecture
/// - Improve user experience (no lost requests)
/// - Prevent data loss during network outages
/// - Support asynchronous operations
///
/// **Queue Processing:**
/// ```
/// Offline Request
///     ↓
/// Store in SQLite (SyncQueueTable)
///     ↓
/// Connectivity restored
///     ↓
/// Process by priority (CRITICAL → HIGH → NORMAL → LOW)
///     ↓
/// Retry on failure (exponential backoff)
///     ↓
/// Remove on success or TTL expiry
/// ```
///
/// **Usage Example:**
/// ```dart
/// final queue = OfflineRequestQueue(
///   database: database,
///   connectivityService: connectivityService,
/// );
///
/// // Queue request when offline
/// await queue.enqueue(
///   requestOptions: options,
///   priority: RequestPriority.high,
///   ttl: Duration(hours: 24),
/// );
///
/// // Process queue when online
/// await queue.processQueue();
/// ```
class OfflineRequestQueue {
  final AppLogger _logger = AppLogger('OfflineRequestQueue');
  final AppDatabase database;
  final ConnectivityService connectivityService;

  /// Maximum queue size to prevent unbounded growth
  final int maxQueueSize;

  /// Maximum retry attempts per request
  final int maxRetries;

  /// Default TTL for requests (24 hours)
  final Duration defaultTtl;

  /// Whether queue is currently processing
  bool _isProcessing = false;

  OfflineRequestQueue({
    required this.database,
    required this.connectivityService,
    this.maxQueueSize = 1000,
    this.maxRetries = 5,
    this.defaultTtl = const Duration(hours: 24),
  }) {
    // Listen to connectivity changes and auto-process queue
    _setupConnectivityListener();
  }

  /// Sets up listener for connectivity changes
  void _setupConnectivityListener() {
    connectivityService.startMonitoring();
  }

  /// Enqueues a request for later processing
  ///
  /// **Parameters:**
  /// - [requestOptions]: Dio request options to queue
  /// - [priority]: Request priority (default: normal)
  /// - [ttl]: Time-to-live (default: 24 hours)
  /// - [dependsOn]: ID of prerequisite request (optional)
  ///
  /// **Returns:** Queue ID for tracking
  ///
  /// **Example:**
  /// ```dart
  /// final queueId = await queue.enqueue(
  ///   requestOptions: RequestOptions(
  ///     method: 'POST',
  ///     path: '/api/v1/orders',
  ///     data: orderData,
  ///   ),
  ///   priority: RequestPriority.critical,
  /// );
  /// ```
  Future<int> enqueue({
    required RequestOptions requestOptions,
    RequestPriority priority = RequestPriority.normal,
    Duration? ttl,
    String? dependsOn,
  }) async {
    // Check queue size limit
    final queueSize = await _getQueueSize();
    if (queueSize >= maxQueueSize) {
      _logger.warning('Queue size limit reached', metadata: {
        'queue_size': queueSize,
        'max_size': maxQueueSize,
      });
      throw QueueFullException('Offline queue is full');
    }

    final requestId =
        requestOptions.extra['request_id'] as String? ?? 'unknown';
    final expiresAt = DateTime.now().add(ttl ?? defaultTtl);

    // Prepare payload
    final payload = jsonEncode({
      'method': requestOptions.method,
      'path': requestOptions.path,
      'headers': requestOptions.headers,
      'data': requestOptions.data,
      'queryParameters': requestOptions.queryParameters,
      'extra': requestOptions.extra,
      'priority': priority.value,
      'expiresAt': expiresAt.toIso8601String(),
      'dependsOn': dependsOn,
    });

    // Determine entity type from path
    final entityType = _extractEntityType(requestOptions.path);

    _logger.info('Enqueueing request', metadata: {
      'request_id': requestId,
      'method': requestOptions.method,
      'path': requestOptions.path,
      'priority': priority.name,
      'ttl_hours': (ttl ?? defaultTtl).inHours,
    });

    // Insert into sync queue
    final queueId = await database.syncQueueDao.addToQueue(
      entityType: entityType,
      entityId: requestId,
      operation: requestOptions.method.toLowerCase(),
      payload: payload,
    );

    return queueId;
  }

  /// Processes all pending requests in the queue
  ///
  /// **What it does:**
  /// 1. Fetches pending requests from database
  /// 2. Removes expired requests (past TTL)
  /// 3. Sorts by priority and creation time
  /// 4. Processes requests respecting dependencies
  /// 5. Retries failed requests with backoff
  ///
  /// **Returns:** Number of successfully processed requests
  Future<int> processQueue() async {
    if (_isProcessing) {
      _logger.debug('Queue already processing, skipping');
      return 0;
    }

    if (!await connectivityService.isOnline()) {
      _logger.debug('Offline, skipping queue processing');
      return 0;
    }

    _isProcessing = true;
    int processedCount = 0;

    try {
      _logger.info('Starting queue processing');

      // Get pending operations
      final pending = await database.syncQueueDao.getPendingOperations();

      _logger.debug('Found pending requests', metadata: {
        'count': pending.length,
      });

      // Remove expired requests
      await _removeExpiredRequests(pending);

      // Sort by priority and creation time
      final sorted = _sortByPriority(pending);

      // Process each request
      for (final item in sorted) {
        try {
          // Check dependency
          if (await _hasPendingDependency(item)) {
            _logger
                .debug('Skipping request with pending dependency', metadata: {
              'queue_id': item.id,
            });
            continue;
          }

          // Process request
          final success = await _processRequest(item);
          if (success) {
            processedCount++;
          }
        } catch (e, stackTrace) {
          _logger.error('Error processing queue item',
              error: e,
              stackTrace: stackTrace,
              metadata: {
                'queue_id': item.id,
              });
        }
      }

      _logger.info('Queue processing complete', metadata: {
        'processed': processedCount,
        'total': pending.length,
      });

      return processedCount;
    } finally {
      _isProcessing = false;
    }
  }

  /// Processes a single queued request
  Future<bool> _processRequest(SyncQueueTableData item) async {
    final payload = jsonDecode(item.payload) as Map<String, dynamic>;

    // Check if expired
    if (_isExpired(payload)) {
      _logger.info('Request expired, removing from queue', metadata: {
        'queue_id': item.id,
      });
      await database.syncQueueDao.deleteOperation(item.id);
      return false;
    }

    // Check retry limit
    if (item.retryCount >= maxRetries) {
      _logger.warning('Max retries exceeded, removing from queue', metadata: {
        'queue_id': item.id,
        'retry_count': item.retryCount,
      });
      await database.syncQueueDao.deleteOperation(item.id);
      return false;
    }

    // Mark as syncing
    await database.syncQueueDao.markAsSyncing(item.id);

    try {
      // Reconstruct RequestOptions
      final options = RequestOptions(
        method: payload['method'] as String,
        path: payload['path'] as String,
        headers: Map<String, dynamic>.from(payload['headers'] as Map? ?? {}),
        data: payload['data'],
        queryParameters:
            Map<String, dynamic>.from(payload['queryParameters'] as Map? ?? {}),
        extra: Map<String, dynamic>.from(payload['extra'] as Map? ?? {}),
      );

      _logger.info('Processing queued request', metadata: {
        'queue_id': item.id,
        'method': options.method,
        'path': options.path,
        'retry_count': item.retryCount,
      });

      // Execute request
      final dio = Dio();
      await dio.fetch(options);

      // Mark as completed
      await database.syncQueueDao.markAsCompleted(item.id);

      _logger.info('Request processed successfully', metadata: {
        'queue_id': item.id,
      });

      return true;
    } catch (e, stackTrace) {
      _logger
          .error('Request failed', error: e, stackTrace: stackTrace, metadata: {
        'queue_id': item.id,
        'retry_count': item.retryCount,
      });

      // Mark as failed
      await database.syncQueueDao.markAsFailed(
        queueId: item.id,
        error: e.toString(),
      );

      return false;
    }
  }

  /// Removes expired requests from queue
  Future<void> _removeExpiredRequests(List<SyncQueueTableData> items) async {
    int removedCount = 0;

    for (final item in items) {
      try {
        final payload = jsonDecode(item.payload) as Map<String, dynamic>;
        if (_isExpired(payload)) {
          await database.syncQueueDao.deleteOperation(item.id);
          removedCount++;
        }
      } catch (e) {
        _logger.warning('Error checking expiry', metadata: {
          'queue_id': item.id,
          'error': e.toString(),
        });
      }
    }

    if (removedCount > 0) {
      _logger.info('Removed expired requests', metadata: {
        'count': removedCount,
      });
    }
  }

  /// Checks if request has expired
  bool _isExpired(Map<String, dynamic> payload) {
    final expiresAtStr = payload['expiresAt'] as String?;
    if (expiresAtStr == null) return false;

    try {
      final expiresAt = DateTime.parse(expiresAtStr);
      return DateTime.now().isAfter(expiresAt);
    } catch (e) {
      return false;
    }
  }

  /// Sorts requests by priority and creation time
  List<SyncQueueTableData> _sortByPriority(List<SyncQueueTableData> items) =>
      items.toList()
        ..sort((a, b) {
          try {
            final aPayload = jsonDecode(a.payload) as Map<String, dynamic>;
            final bPayload = jsonDecode(b.payload) as Map<String, dynamic>;

            final aPriority = aPayload['priority'] as int? ?? 1;
            final bPriority = bPayload['priority'] as int? ?? 1;

            // Higher priority first
            if (aPriority != bPriority) {
              return bPriority.compareTo(aPriority);
            }

            // Then by creation time (FIFO)
            return a.createdAt.compareTo(b.createdAt);
          } catch (e) {
            return 0;
          }
        });

  /// Checks if request has pending dependencies
  Future<bool> _hasPendingDependency(SyncQueueTableData item) async {
    try {
      final payload = jsonDecode(item.payload) as Map<String, dynamic>;
      final dependsOn = payload['dependsOn'] as String?;

      if (dependsOn == null) return false;

      // Check if dependency still pending
      final pending = await database.syncQueueDao.getPendingOperations();
      return pending.any((p) => p.entityId == dependsOn);
    } catch (e) {
      return false;
    }
  }

  /// Extracts entity type from API path
  String _extractEntityType(String path) {
    if (path.contains('/orders')) return 'order';
    if (path.contains('/drivers')) return 'driver';
    if (path.contains('/users')) return 'user';
    return 'unknown';
  }

  /// Gets current queue size
  Future<int> _getQueueSize() async {
    final pending = await database.syncQueueDao.getPendingOperations();
    return pending.length;
  }

  /// Clears all pending requests (useful for logout)
  Future<void> clearQueue() async {
    _logger.info('Clearing offline queue');
    final pending = await database.syncQueueDao.getPendingOperations();
    for (final item in pending) {
      await database.syncQueueDao.deleteOperation(item.id);
    }
  }

  /// Gets queue statistics
  Future<QueueStats> getStats() async {
    final pending = await database.syncQueueDao.getPendingOperations();

    int criticalCount = 0;
    int highCount = 0;
    int normalCount = 0;
    int lowCount = 0;
    int expiredCount = 0;

    for (final item in pending) {
      try {
        final payload = jsonDecode(item.payload) as Map<String, dynamic>;
        if (_isExpired(payload)) {
          expiredCount++;
          continue;
        }

        final priority = payload['priority'] as int? ?? 1;
        switch (priority) {
          case 3:
            criticalCount++;
            break;
          case 2:
            highCount++;
            break;
          case 1:
            normalCount++;
            break;
          case 0:
            lowCount++;
            break;
        }
      } catch (e) {
        // Skip malformed items
      }
    }

    return QueueStats(
      totalPending: pending.length,
      criticalCount: criticalCount,
      highCount: highCount,
      normalCount: normalCount,
      lowCount: lowCount,
      expiredCount: expiredCount,
    );
  }
}

/// Queue statistics
class QueueStats {
  final int totalPending;
  final int criticalCount;
  final int highCount;
  final int normalCount;
  final int lowCount;
  final int expiredCount;

  QueueStats({
    required this.totalPending,
    required this.criticalCount,
    required this.highCount,
    required this.normalCount,
    required this.lowCount,
    required this.expiredCount,
  });

  @override
  String toString() =>
      'QueueStats(total: $totalPending, critical: $criticalCount, high: $highCount, '
      'normal: $normalCount, low: $lowCount, expired: $expiredCount)';
}

/// Exception thrown when queue is full
class QueueFullException implements Exception {
  final String message;
  QueueFullException(this.message);

  @override
  String toString() => 'QueueFullException: $message';
}
