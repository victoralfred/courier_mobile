import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:delivery_app/core/database/app_database.dart';
import 'package:delivery_app/core/network/api_client.dart';

/// Service for synchronizing offline operations with the backend
///
/// Processes the sync queue and uploads pending operations
/// when the device has network connectivity.
class SyncService {
  final AppDatabase _database;
  final ApiClient _apiClient;

  SyncService({
    required AppDatabase database,
    required ApiClient apiClient,
  })  : _database = database,
        _apiClient = apiClient;

  /// Syncs all pending operations in the queue
  Future<SyncResult> syncPendingOperations() async {
    try {
      // Get all pending operations
      final pendingOperations =
          await _database.syncQueueDao.getPendingOperations();

      if (pendingOperations.isEmpty) {
        return SyncResult(
          success: true,
          processedCount: 0,
          failedCount: 0,
          message: 'No pending operations to sync',
        );
      }

      int successCount = 0;
      int failureCount = 0;

      // Process each operation
      for (final operation in pendingOperations) {
        final result = await processSyncQueueItem(operation);
        if (result) {
          successCount++;
        } else {
          failureCount++;
        }
      }

      return SyncResult(
        success: failureCount == 0,
        processedCount: successCount,
        failedCount: failureCount,
        message: 'Synced $successCount operations, $failureCount failed',
      );
    } catch (e) {
      debugPrint('Sync failed: $e');
      return SyncResult(
        success: false,
        processedCount: 0,
        failedCount: 0,
        message: 'Sync service error: ${e.toString()}',
      );
    }
  }

  /// Process a single sync queue item
  Future<bool> processSyncQueueItem(SyncQueueTableData item) async {
    try {
      // Mark as syncing
      await _database.syncQueueDao.markAsSyncing(item.id);

      // Parse payload
      final payload = jsonDecode(item.payload) as Map<String, dynamic>;
      final endpoint = payload['endpoint'] as String;
      final data = payload['data'] as Map<String, dynamic>?;

      // Debug logging
      debugPrint('=== SYNC SERVICE DEBUG ===');
      debugPrint('Processing sync item: ${item.id}');
      debugPrint('Endpoint: $endpoint');
      debugPrint('Entity: ${item.entityType} - ${item.entityId}');
      debugPrint('Operation: ${item.operation}');
      debugPrint('Current auth token: ${_apiClient.getAuthToken() ?? "NO TOKEN"}');
      debugPrint('Data being sent: ${jsonEncode(data)}');
      debugPrint('========================');

      // Execute the appropriate HTTP request
      Response response;

      if (endpoint.startsWith('POST')) {
        final path = _extractPath(endpoint);
        debugPrint('Making POST request to: $path');
        response = await _apiClient.post(path, data: data);
      } else if (endpoint.startsWith('PUT')) {
        final path = _extractPath(endpoint);
        debugPrint('Making PUT request to: $path');
        response = await _apiClient.put(path, data: data);
      } else if (endpoint.startsWith('DELETE')) {
        final path = _extractPath(endpoint);
        debugPrint('Making DELETE request to: $path');
        response = await _apiClient.delete(path, data: data);
      } else {
        throw Exception('Unsupported HTTP method in endpoint: $endpoint');
      }

      // Check response status
      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        // Success - mark as completed
        await _database.syncQueueDao.markAsCompleted(item.id);
        return true;
      } else if (response.statusCode == 409) {
        // Conflict - data was modified on server
        await _database.syncQueueDao.markAsFailed(
          queueId: item.id,
          error: 'Conflict: Data modified on server (HTTP 409)',
        );
        return false;
      } else {
        // Other error
        await _database.syncQueueDao.markAsFailed(
          queueId: item.id,
          error:
              'HTTP ${response.statusCode}: ${response.statusMessage ?? "Unknown error"}',
        );
        return false;
      }
    } on DioException catch (e) {
      // Network error
      await _database.syncQueueDao.markAsFailed(
        queueId: item.id,
        error: 'Network error: ${e.message}',
      );
      return false;
    } catch (e) {
      // Other error
      await _database.syncQueueDao.markAsFailed(
        queueId: item.id,
        error: 'Sync error: ${e.toString()}',
      );
      return false;
    }
  }

  /// Extract path from endpoint string (e.g., "POST /api/v1/orders" -> "/api/v1/orders")
  String _extractPath(String endpoint) {
    final parts = endpoint.split(' ');
    if (parts.length >= 2) {
      return parts[1];
    }
    throw Exception('Invalid endpoint format: $endpoint');
  }

  /// Retry failed operations
  Future<SyncResult> retryFailedOperations() async {
    try {
      final failedCount = await _database.syncQueueDao.getFailedCount();

      if (failedCount == 0) {
        return SyncResult(
          success: true,
          processedCount: 0,
          failedCount: 0,
          message: 'No failed operations to retry',
        );
      }

      // Get pending operations (retry will move failed back to pending)
      final pendingOperations =
          await _database.syncQueueDao.getPendingOperations();

      int successCount = 0;
      int failureCount = 0;

      for (final operation in pendingOperations) {
        // Only retry if retry count is less than max
        if (operation.retryCount < 3) {
          await _database.syncQueueDao.retryOperation(operation.id);
          final result = await processSyncQueueItem(operation);
          if (result) {
            successCount++;
          } else {
            failureCount++;
          }
        }
      }

      return SyncResult(
        success: failureCount == 0,
        processedCount: successCount,
        failedCount: failureCount,
        message: 'Retried $successCount operations, $failureCount failed',
      );
    } catch (e) {
      debugPrint('Retry failed: $e');
      return SyncResult(
        success: false,
        processedCount: 0,
        failedCount: 0,
        message: 'Retry error: ${e.toString()}',
      );
    }
  }

  /// Clean up old completed operations
  Future<void> cleanupCompletedOperations({int olderThanDays = 7}) async {
    try {
      final deletedCount =
          await _database.syncQueueDao.deleteCompletedOperations(
        olderThanDays: olderThanDays,
      );
      debugPrint('Cleaned up $deletedCount completed sync operations');
    } catch (e) {
      debugPrint('Cleanup failed: $e');
    }
  }

  /// Get sync statistics
  Future<SyncStatistics> getSyncStatistics() async {
    try {
      final pending = await _database.syncQueueDao.getPendingOperations();
      final failedCount = await _database.syncQueueDao.getFailedCount();

      return SyncStatistics(
        pendingCount: pending.length,
        failedCount: failedCount,
        lastSync: DateTime.now(), // TODO: Store last sync time
      );
    } catch (e) {
      debugPrint('Failed to get sync statistics: $e');
      return SyncStatistics(
        pendingCount: 0,
        failedCount: 0,
        lastSync: null,
      );
    }
  }
}

/// Result of a sync operation
class SyncResult {
  final bool success;
  final int processedCount;
  final int failedCount;
  final String message;

  SyncResult({
    required this.success,
    required this.processedCount,
    required this.failedCount,
    required this.message,
  });

  @override
  String toString() =>
      'SyncResult(success: $success, processed: $processedCount, failed: $failedCount, message: $message)';
}

/// Sync statistics
class SyncStatistics {
  final int pendingCount;
  final int failedCount;
  final DateTime? lastSync;

  SyncStatistics({
    required this.pendingCount,
    required this.failedCount,
    this.lastSync,
  });

  bool get hasPending => pendingCount > 0;
  bool get hasFailed => failedCount > 0;

  @override
  String toString() =>
      'SyncStatistics(pending: $pendingCount, failed: $failedCount, lastSync: $lastSync)';
}
