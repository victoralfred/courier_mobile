import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../database/app_database.dart';
import '../../network/connectivity_service.dart';
import '../../services/app_logger.dart';
import 'connectivity_state.dart';

/// Cubit for managing app-wide connectivity and sync state.
///
/// WHAT: Centralized state management for network connectivity and offline sync status.
/// Bridges infrastructure layer (ConnectivityService) with UI layer through reactive state.
///
/// WHY:
/// - Provides single source of truth for connectivity status across entire app
/// - Enables reactive UI updates based on network changes and sync progress
/// - Separates connectivity monitoring (infrastructure) from state management (business logic)
/// - Allows any widget to access connectivity state without prop drilling
///
/// HOW:
/// 1. Monitors network connectivity via connectivity_plus stream
/// 2. Watches pending sync operation count via SyncQueueDao stream
/// 3. Triggers automatic sync when connectivity is restored
/// 4. Emits combined state (online/offline + pending count) for UI consumption
///
/// LIFECYCLE:
/// ```
/// Initial → startMonitoring() → Online/Offline → [network changes] → state updates
///                                      ↓
///                              [pending count changes] → state updates
///                                      ↓
///                              [offline → online] → trigger sync → Syncing → Online
/// ```
///
/// ARCHITECTURE:
/// Layer 1 (Infrastructure): ConnectivityService - Background automation
/// Layer 2 (State): ConnectivityCubit - Reactive state management ← THIS CLASS
/// Layer 3 (UI): Widgets - Visual indicators
///
/// SOLID PRINCIPLES:
/// - Single Responsibility: Only manages connectivity state, delegates sync to service
/// - Open/Closed: Extend via new state types, not modifications
/// - Liskov Substitution: All states implement ConnectivityState contract
/// - Dependency Inversion: Depends on abstractions (injected dependencies)
///
/// USAGE:
/// ```dart
/// // In app initialization (app.dart):
/// BlocProvider<ConnectivityCubit>(
///   create: (context) => getIt<ConnectivityCubit>()..startMonitoring(),
///   child: MyApp(),
/// )
///
/// // In widgets:
/// BlocBuilder<ConnectivityCubit, ConnectivityState>(
///   builder: (context, state) {
///     if (state is ConnectivityOffline) {
///       return OfflineBanner(pendingCount: state.pendingCount);
///     }
///     return SizedBox.shrink();
///   },
/// )
/// ```
///
/// DEPENDENCIES:
/// - ConnectivityService: Monitors network, triggers background sync
/// - AppDatabase: Provides access to SyncQueueDao for pending operation count stream
/// - Connectivity: Direct access to connectivity_plus for reactive updates
class ConnectivityCubit extends Cubit<ConnectivityState> {
  static final _logger = AppLogger('ConnectivityCubit');

  final ConnectivityService _connectivityService;
  final AppDatabase _database;
  final Connectivity _connectivity;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<int>? _pendingCountSubscription;

  // Track previous state to detect transitions
  bool _wasOffline = false;
  int _currentPendingCount = 0;
  bool _isSyncing = false;

  ConnectivityCubit({
    required ConnectivityService connectivityService,
    required AppDatabase database,
    required Connectivity connectivity,
  })  : _connectivityService = connectivityService,
        _database = database,
        _connectivity = connectivity,
        super(const ConnectivityInitial());

  /// Start monitoring connectivity and sync status.
  ///
  /// WHAT: Initializes stream listeners for network and pending count changes.
  ///
  /// WHY: Must be called explicitly (not in constructor) to allow proper
  /// BlocProvider setup and avoid emitting states before widget tree is ready.
  ///
  /// WHEN: Call immediately after ConnectivityCubit is provided to widget tree:
  /// ```dart
  /// BlocProvider(
  ///   create: (context) => getIt<ConnectivityCubit>()..startMonitoring(),
  /// )
  /// ```
  ///
  /// BEHAVIOR:
  /// 1. Checks initial connectivity status
  /// 2. Subscribes to connectivity_plus stream for real-time network changes
  /// 3. Subscribes to SyncQueueDao stream for pending count updates
  /// 4. Starts ConnectivityService background monitoring (for auto-sync)
  /// 5. Emits initial state based on current connectivity + pending count
  Future<void> startMonitoring() async {
    try {
      _logger.info('Starting connectivity monitoring');

      // Subscribe to connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _handleConnectivityChange,
        onError: (error) {
          _logger.error('Connectivity stream error', metadata: {
            'error': error.toString(),
          });
        },
      );

      // Subscribe to pending sync count changes
      _pendingCountSubscription = _database.syncQueueDao.watchPendingCount().listen(
        _handlePendingCountChange,
        onError: (error) {
          _logger.error('Pending count stream error', metadata: {
            'error': error.toString(),
          });
        },
      );

      // Start background monitoring (for automatic sync on reconnection)
      await _connectivityService.startMonitoring();

      // Emit initial state based on current connectivity
      final initialResults = await _connectivity.checkConnectivity();
      final isOffline = _isOffline(initialResults);
      _wasOffline = isOffline;

      // Initial pending count will come from stream
      _logger.debug('Connectivity monitoring started', metadata: {
        'initiallyOffline': isOffline,
      });
    } catch (e, stackTrace) {
      _logger.error('Failed to start connectivity monitoring', metadata: {
        'error': e.toString(),
        'stackTrace': stackTrace.toString(),
      });
    }
  }

  /// Stop monitoring connectivity and clean up resources.
  ///
  /// WHAT: Cancels stream subscriptions and stops background monitoring.
  ///
  /// WHY: Prevents memory leaks and unnecessary background processing when
  /// cubit is disposed (e.g., app termination, hot reload).
  ///
  /// WHEN: Called automatically by BLoC library when cubit is closed.
  @override
  Future<void> close() async {
    _logger.info('Stopping connectivity monitoring');
    await _connectivitySubscription?.cancel();
    await _pendingCountSubscription?.cancel();
    await _connectivityService.stopMonitoring();
    return super.close();
  }

  /// Handle connectivity changes from connectivity_plus stream.
  ///
  /// WHAT: Processes network connectivity changes and updates state accordingly.
  ///
  /// WHY: Provides real-time feedback to users about network status and
  /// triggers sync when connection is restored after being offline.
  ///
  /// BEHAVIOR:
  /// - Offline → Online: Triggers sync, emits ConnectivitySyncing
  /// - Online → Offline: Emits ConnectivityOffline with current pending count
  /// - Online → Online: No state change (unless pending count changed)
  ///
  /// PARAMETERS:
  /// - results: List of active connectivity types (wifi, mobile, ethernet, etc.)
  ///   Empty list or [ConnectivityResult.none] indicates offline
  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final isCurrentlyOffline = _isOffline(results);

    _logger.info('Connectivity changed', metadata: {
      'wasOffline': _wasOffline,
      'isCurrentlyOffline': isCurrentlyOffline,
      'results': results.map((r) => r.name).toList(),
      'pendingCount': _currentPendingCount,
    });

    // Detect offline → online transition
    if (_wasOffline && !isCurrentlyOffline) {
      _logger.info('Connection restored, triggering sync');
      _triggerSync();
    } else {
      // Emit appropriate state based on current connectivity
      _emitStateForConnectivity(isCurrentlyOffline);
    }

    _wasOffline = isCurrentlyOffline;
  }

  /// Handle pending sync count changes from SyncQueueDao stream.
  ///
  /// WHAT: Updates state when number of pending sync operations changes.
  ///
  /// WHY: Shows users real-time count of queued operations and sync progress.
  /// Count changes happen when:
  /// - User performs offline operations (count increases)
  /// - Sync completes successfully (count decreases)
  /// - Sync fails and operation is retried (count may stay same)
  ///
  /// BEHAVIOR:
  /// - If syncing and count reaches 0: Transition to ConnectivityOnline
  /// - If offline: Update ConnectivityOffline with new count
  /// - If online: Update ConnectivityOnline with new count
  ///
  /// PARAMETERS:
  /// - count: Current number of pending operations in sync queue
  void _handlePendingCountChange(int count) {
    _logger.debug('Pending count changed', metadata: {
      'previousCount': _currentPendingCount,
      'newCount': count,
      'isSyncing': _isSyncing,
      'wasOffline': _wasOffline,
    });

    _currentPendingCount = count;

    // If we were syncing and count dropped to 0, sync completed
    if (_isSyncing && count == 0) {
      _logger.info('Sync completed successfully');
      _isSyncing = false;
      emit(const ConnectivityOnline(pendingCount: 0));
    } else {
      // Update current state with new count
      _emitStateForConnectivity(_wasOffline);
    }
  }

  /// Trigger background sync when connection is restored.
  ///
  /// WHAT: Initiates sync process and emits ConnectivitySyncing state.
  ///
  /// WHY: Provides visual feedback during sync and prevents duplicate syncs.
  ///
  /// BEHAVIOR:
  /// 1. Sets _isSyncing flag to prevent concurrent syncs
  /// 2. Emits ConnectivitySyncing with current pending count
  /// 3. Calls ConnectivityService.checkAndSync() to process queue
  /// 4. State transitions happen via _handlePendingCountChange as count decreases
  ///
  /// ERROR HANDLING:
  /// - If sync fails, ConnectivityService logs error
  /// - State remains ConnectivitySyncing until count changes or connection lost
  /// - User can retry by toggling airplane mode or app restart
  Future<void> _triggerSync() async {
    if (_isSyncing) {
      _logger.debug('Sync already in progress, skipping');
      return;
    }

    _isSyncing = true;

    // Only show syncing state if there are pending operations
    if (_currentPendingCount > 0) {
      emit(ConnectivitySyncing(pendingCount: _currentPendingCount));
    }

    try {
      final syncTriggered = await _connectivityService.checkAndSync();
      _logger.info('Sync trigger result', metadata: {
        'syncTriggered': syncTriggered,
        'pendingCount': _currentPendingCount,
      });

      // If no pending operations, immediately transition to online
      // Otherwise, state transition happens via _handlePendingCountChange
      // when pending count drops to 0
      if (_currentPendingCount == 0) {
        _logger.info('No pending operations, transitioning to online');
        _isSyncing = false;
        emit(const ConnectivityOnline(pendingCount: 0));
      }
    } catch (e) {
      _logger.error('Sync trigger failed', metadata: {
        'error': e.toString(),
      });
      _isSyncing = false;
      // Emit online state with pending count to show sync couldn't start
      emit(ConnectivityOnline(pendingCount: _currentPendingCount));
    }
  }

  /// Emit appropriate state based on current connectivity and pending count.
  ///
  /// WHAT: Helper method to determine and emit correct state.
  ///
  /// WHY: Centralizes state emission logic to ensure consistency.
  ///
  /// STATE LOGIC:
  /// - If syncing: ConnectivitySyncing(pendingCount)
  /// - Else if offline: ConnectivityOffline(pendingCount)
  /// - Else (online): ConnectivityOnline(pendingCount)
  ///
  /// PARAMETERS:
  /// - isOffline: Whether device currently has no network connection
  void _emitStateForConnectivity(bool isOffline) {
    if (_isSyncing) {
      // Don't change state while syncing, let pending count changes handle it
      _logger.debug('Skipping state emission while syncing');
      return;
    }

    if (isOffline) {
      _logger.info('Emitting ConnectivityOffline state', metadata: {
        'pendingCount': _currentPendingCount,
      });
      emit(ConnectivityOffline(pendingCount: _currentPendingCount));
    } else {
      _logger.info('Emitting ConnectivityOnline state', metadata: {
        'pendingCount': _currentPendingCount,
      });
      emit(ConnectivityOnline(pendingCount: _currentPendingCount));
    }
  }

  /// Check if connectivity results indicate offline status.
  ///
  /// WHAT: Determines if device has no network connectivity.
  ///
  /// WHY: connectivity_plus can return multiple results (wifi + mobile),
  /// need to check if ALL results indicate no connection.
  ///
  /// LOGIC:
  /// - Empty list = offline (no connectivity available)
  /// - Contains ConnectivityResult.none = offline
  /// - Otherwise = online (at least one connection type available)
  ///
  /// RETURNS: true if offline, false if any connection available
  bool _isOffline(List<ConnectivityResult> results) =>
      results.isEmpty || results.contains(ConnectivityResult.none);
}
