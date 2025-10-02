import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:delivery_app/core/sync/sync_service.dart';

/// Service for monitoring network connectivity and triggering sync
///
/// Listens to connectivity changes and automatically triggers sync
/// when the device comes online.
class ConnectivityService {
  final Connectivity _connectivity;
  final SyncService _syncService;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _wasOffline = false;

  ConnectivityService({
    required Connectivity connectivity,
    required SyncService syncService,
  })  : _connectivity = connectivity,
        _syncService = syncService;

  /// Start monitoring connectivity changes
  Future<void> startMonitoring() async {
    // Check initial connectivity status
    final initialStatus = await _connectivity.checkConnectivity();
    _wasOffline = _isOffline(initialStatus);

    // Listen to connectivity changes
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_handleConnectivityChange);

    debugPrint('ConnectivityService: Started monitoring network connectivity');
  }

  /// Stop monitoring connectivity changes
  Future<void> stopMonitoring() async {
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    debugPrint('ConnectivityService: Stopped monitoring network connectivity');
  }

  /// Handle connectivity state changes
  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final isCurrentlyOffline = _isOffline(results);

    debugPrint(
        'ConnectivityService: Connectivity changed to ${results.join(", ")}');

    // If we were offline and now we're online, trigger sync
    if (_wasOffline && !isCurrentlyOffline) {
      debugPrint('ConnectivityService: Device came online, triggering sync...');
      _triggerSync();
    }

    _wasOffline = isCurrentlyOffline;
  }

  /// Check if the device is offline
  // ignore: prefer_expression_function_bodies
  bool _isOffline(List<ConnectivityResult> results) {
    // Consider device offline if the only result is 'none'
    return results.length == 1 && results.first == ConnectivityResult.none;
  }

  /// Trigger sync operation
  Future<void> _triggerSync() async {
    try {
      debugPrint('ConnectivityService: Starting sync operation...');
      final result = await _syncService.syncPendingOperations();

      if (result.success) {
        debugPrint(
            'ConnectivityService: Sync completed successfully - ${result.message}');
      } else {
        debugPrint(
            'ConnectivityService: Sync completed with errors - ${result.message}');
      }
    } catch (e) {
      debugPrint('ConnectivityService: Sync failed with error: $e');
    }
  }

  /// Manually check connectivity and sync if online
  Future<bool> checkAndSync() async {
    try {
      final connectivityResults = await _connectivity.checkConnectivity();
      final isOffline = _isOffline(connectivityResults);

      if (!isOffline) {
        debugPrint(
            'ConnectivityService: Device is online, triggering manual sync...');
        await _triggerSync();
        return true;
      } else {
        debugPrint('ConnectivityService: Device is offline, cannot sync');
        return false;
      }
    } catch (e) {
      debugPrint('ConnectivityService: Check and sync failed: $e');
      return false;
    }
  }

  /// Check if device is currently online
  Future<bool> isOnline() async {
    try {
      final connectivityResults = await _connectivity.checkConnectivity();
      return !_isOffline(connectivityResults);
    } catch (e) {
      debugPrint('ConnectivityService: Failed to check connectivity: $e');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
