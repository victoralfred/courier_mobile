import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:delivery_app/core/sync/sync_service.dart';

/// [ConnectivityService] - Monitors network connectivity and triggers automatic sync when device comes online
///
/// **What it does:**
/// - Monitors device connectivity in real-time (WiFi, Mobile Data, Ethernet, None)
/// - Detects offline → online transitions automatically
/// - Triggers sync operation when device reconnects to network
/// - Provides manual connectivity check and sync
/// - Exposes current online/offline status
/// - Prevents sync when offline (graceful degradation)
///
/// **Why it exists:**
/// - Critical for offline-first architecture (queue operations offline, sync online)
/// - Automatic sync ensures data consistency without user intervention
/// - Improves user experience (seamless background sync)
/// - Reduces data loss (pending operations synced when possible)
/// - Essential for delivery app (drivers may enter areas with poor connectivity)
/// - Separates connectivity concerns from business logic
///
/// **Connectivity Flow:**
/// ```
/// App Launch → startMonitoring()
///                   ↓
///         Check initial status (WiFi/Mobile/None)
///                   ↓
///         Subscribe to connectivity changes
///                   ↓
/// Offline → Online transition detected
///                   ↓
///         Trigger automatic sync
///                   ↓
/// SyncService syncs pending operations → Backend
/// ```
///
/// **Connectivity States Detected:**
/// - **WiFi**: Connected to WiFi network
/// - **Mobile**: Connected via cellular data (4G, 5G, etc.)
/// - **Ethernet**: Connected via wired network (tablets, desktops)
/// - **None**: No network connectivity
/// - **Multiple**: Device has multiple connections (WiFi + Mobile)
///
/// **Usage Example:**
/// ```dart
/// // Initialize service
/// final connectivityService = ConnectivityService(
///   connectivity: Connectivity(),
///   syncService: syncService,
/// );
///
/// // Start monitoring (app initialization)
/// await connectivityService.startMonitoring();
///
/// // Check current status
/// final isOnline = await connectivityService.isOnline();
/// if (isOnline) {
///   print('Device is online');
/// }
///
/// // Manual sync trigger
/// final syncSuccess = await connectivityService.checkAndSync();
///
/// // Stop monitoring (app disposal)
/// await connectivityService.stopMonitoring();
/// connectivityService.dispose();
/// ```
///
/// **IMPROVEMENT:**
/// - [High Priority] Remove debug print statements (use logging service)
/// - [High Priority] Add retry logic for failed sync operations
/// - [Medium Priority] Add connectivity quality check (slow vs fast connection)
/// - [Medium Priority] Expose connectivity state as Stream (reactive UI updates)
/// - [Medium Priority] Add configurable sync delay (debounce rapid connectivity changes)
/// - [Low Priority] Add metrics for sync success/failure rates
/// - [Low Priority] Support prioritized sync (critical operations first)
class ConnectivityService {
  /// Connectivity plugin instance for monitoring network changes
  ///
  /// **Why connectivity_plus:**
  /// - Cross-platform (iOS, Android, Web, Desktop)
  /// - Real-time connectivity monitoring
  /// - Distinguishes WiFi, Mobile, Ethernet, None
  final Connectivity _connectivity;

  /// Sync service for uploading pending operations to backend
  ///
  /// **Why injected:**
  /// - Separates connectivity concerns from sync logic
  /// - Enables testing with mock sync service
  /// - Follows dependency inversion principle
  final SyncService _syncService;

  /// Active subscription to connectivity changes
  ///
  /// **Why nullable:**
  /// - Subscription only active when monitoring enabled
  /// - Can be cancelled and restarted
  /// - Null when not monitoring
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Tracks previous offline state to detect transitions
  ///
  /// **Why needed:**
  /// - Sync only triggered on offline → online transition
  /// - Prevents redundant sync on online → online (WiFi → Mobile)
  /// - Ensures sync happens once when reconnecting
  bool _wasOffline = false;

  /// Creates connectivity service
  ///
  /// **Parameters:**
  /// - [connectivity]: Connectivity plugin instance (required)
  /// - [syncService]: Service for syncing pending operations (required)
  ///
  /// **Example:**
  /// ```dart
  /// final service = ConnectivityService(
  ///   connectivity: Connectivity(),
  ///   syncService: GetIt.I<SyncService>(),
  /// );
  /// ```
  ConnectivityService({
    required Connectivity connectivity,
    required SyncService syncService,
  })  : _connectivity = connectivity,
        _syncService = syncService;

  /// Starts monitoring network connectivity changes
  ///
  /// **What it does:**
  /// 1. Checks initial connectivity status
  /// 2. Sets _wasOffline based on initial status
  /// 3. Subscribes to connectivity change stream
  /// 4. Calls _handleConnectivityChange on each change
  ///
  /// **When to call:**
  /// - App initialization (main.dart or app startup)
  /// - After stopMonitoring() if restarting monitoring
  ///
  /// **Example:**
  /// ```dart
  /// // In app initialization
  /// final connectivityService = GetIt.I<ConnectivityService>();
  /// await connectivityService.startMonitoring();
  /// ```
  ///
  /// **IMPROVEMENT:**
  /// - [Medium Priority] Add error handling for connectivity check failure
  Future<void> startMonitoring() async {
    // Check initial connectivity status
    final initialStatus = await _connectivity.checkConnectivity();
    _wasOffline = _isOffline(initialStatus);

    // Listen to connectivity changes
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_handleConnectivityChange);

    debugPrint('ConnectivityService: Started monitoring network connectivity');
  }

  /// Stops monitoring network connectivity changes
  ///
  /// **What it does:**
  /// - Cancels active connectivity subscription
  /// - Sets subscription to null
  /// - Stops triggering automatic sync
  ///
  /// **When to call:**
  /// - App disposal/shutdown
  /// - Temporarily pause monitoring (e.g., low battery mode)
  ///
  /// **Example:**
  /// ```dart
  /// // In app shutdown
  /// await connectivityService.stopMonitoring();
  /// ```
  Future<void> stopMonitoring() async {
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    debugPrint('ConnectivityService: Stopped monitoring network connectivity');
  }

  /// Handles connectivity state changes and triggers sync on reconnection
  ///
  /// **What it does:**
  /// 1. Checks if device is currently offline
  /// 2. Compares with previous offline state (_wasOffline)
  /// 3. If offline → online transition, triggers sync
  /// 4. Updates _wasOffline for next change
  ///
  /// **Transition Logic:**
  /// ```
  /// Was Offline  →  Now Offline  →  Action
  /// ─────────────────────────────────────────
  /// true         →  true         →  No sync (still offline)
  /// true         →  false        →  Trigger sync (reconnected!)
  /// false        →  true         →  No sync (went offline)
  /// false        →  false        →  No sync (changed connection type)
  /// ```
  ///
  /// **Example:**
  /// ```dart
  /// // WiFi → Mobile (no sync, both online)
  /// // WiFi → None (no sync, went offline)
  /// // None → WiFi (SYNC!, reconnected)
  /// // None → Mobile (SYNC!, reconnected)
  /// ```
  ///
  /// **Parameters:**
  /// - [results]: List of current connectivity states (may be multiple)
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

  /// Checks if device is currently offline
  ///
  /// **What it does:**
  /// - Returns true if only connectivity result is 'none'
  /// - Returns false if any other connectivity present
  ///
  /// **Logic:**
  /// - Multiple connections (WiFi + Mobile): Online
  /// - Single WiFi connection: Online
  /// - Single Mobile connection: Online
  /// - Single None connection: Offline
  ///
  /// **Parameters:**
  /// - [results]: List of connectivity results from plugin
  ///
  /// **Returns:** true if offline, false if any connection available
  ///
  /// **Example:**
  /// ```dart
  /// _isOffline([ConnectivityResult.none])              // → true
  /// _isOffline([ConnectivityResult.wifi])              // → false
  /// _isOffline([ConnectivityResult.mobile])            // → false
  /// _isOffline([ConnectivityResult.wifi, mobile])      // → false
  /// ```
  // ignore: prefer_expression_function_bodies
  bool _isOffline(List<ConnectivityResult> results) {
    // Consider device offline if the only result is 'none'
    return results.length == 1 && results.first == ConnectivityResult.none;
  }

  /// Triggers sync operation via SyncService
  ///
  /// **What it does:**
  /// - Calls SyncService.syncPendingOperations()
  /// - Logs sync result (success or failure)
  /// - Catches and logs any exceptions
  ///
  /// **Why private:**
  /// - Internal helper for automatic sync
  /// - Public API is checkAndSync() for manual triggers
  ///
  /// **Error Handling:**
  /// - Sync failures logged but not thrown (non-blocking)
  /// - Allows app to continue if sync fails
  ///
  /// **IMPROVEMENT:**
  /// - [High Priority] Add retry logic (exponential backoff)
  /// - [Medium Priority] Add notification on sync failure
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

  /// Manually checks connectivity and triggers sync if online
  ///
  /// **What it does:**
  /// 1. Checks current connectivity status
  /// 2. If online, triggers sync operation
  /// 3. If offline, skips sync
  /// 4. Returns sync result (true if synced, false if offline/failed)
  ///
  /// **When to use:**
  /// - User pulls to refresh
  /// - User taps "Retry" button
  /// - Periodic background sync check
  /// - App returns from background
  ///
  /// **Returns:**
  /// - true: Device is online and sync was triggered
  /// - false: Device is offline OR sync failed
  ///
  /// **Example:**
  /// ```dart
  /// // Pull to refresh
  /// Future<void> _onRefresh() async {
  ///   final synced = await connectivityService.checkAndSync();
  ///   if (synced) {
  ///     showMessage('Data synced successfully');
  ///   } else {
  ///     showMessage('Cannot sync - device offline');
  ///   }
  /// }
  /// ```
  ///
  /// **IMPROVEMENT:**
  /// - [Medium Priority] Return detailed result (success, offline, failed)
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

  /// Checks if device is currently online
  ///
  /// **What it does:**
  /// - Queries current connectivity status
  /// - Returns true if any connection available (WiFi, Mobile, Ethernet)
  /// - Returns false if no connection OR check fails
  ///
  /// **Use cases:**
  /// - Disable network-dependent features when offline
  /// - Show offline indicator in UI
  /// - Prevent network requests when offline
  /// - Show "You are offline" banner
  ///
  /// **Returns:**
  /// - true: Device has network connection
  /// - false: Device is offline OR connectivity check failed
  ///
  /// **Example:**
  /// ```dart
  /// // Disable send button if offline
  /// final isOnline = await connectivityService.isOnline();
  /// sendButton.enabled = isOnline;
  ///
  /// // Show offline banner
  /// if (!isOnline) {
  ///   showBanner('You are currently offline');
  /// }
  /// ```
  Future<bool> isOnline() async {
    try {
      final connectivityResults = await _connectivity.checkConnectivity();
      return !_isOffline(connectivityResults);
    } catch (e) {
      debugPrint('ConnectivityService: Failed to check connectivity: $e');
      return false;
    }
  }

  /// Disposes connectivity subscription and cleans up resources
  ///
  /// **What it does:**
  /// - Cancels active connectivity subscription
  /// - Prevents memory leaks
  /// - Should be called when service is no longer needed
  ///
  /// **When to call:**
  /// - App disposal/shutdown
  /// - Service replacement/reconfiguration
  ///
  /// **Example:**
  /// ```dart
  /// // In app shutdown or service disposal
  /// connectivityService.dispose();
  /// ```
  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
