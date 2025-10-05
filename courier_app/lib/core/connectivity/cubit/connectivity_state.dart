import 'package:equatable/equatable.dart';

/// Base class for connectivity states.
///
/// WHAT: Represents the current network connectivity and sync state of the app.
///
/// WHY: Provides a type-safe way to represent different connectivity scenarios
/// and their associated data (like pending sync count). Enables reactive UI
/// updates based on connectivity changes.
///
/// HOW: Extended by concrete state classes representing specific scenarios:
/// - Initial: Before first connectivity check
/// - Online: Connected with optional pending sync operations
/// - Offline: No connection with queued operations waiting
/// - Syncing: Actively synchronizing queued operations
///
/// DESIGN PATTERNS:
/// - State Pattern: Different states with specific behaviors
/// - Value Object: Immutable state with equality based on values
///
/// SOLID PRINCIPLES:
/// - Single Responsibility: Only represents connectivity state
/// - Open/Closed: Can add new states without modifying existing ones
/// - Liskov Substitution: All states can be used interchangeably
abstract class ConnectivityState extends Equatable {
  const ConnectivityState();

  @override
  List<Object?> get props => [];
}

/// Initial state before first connectivity check.
///
/// WHAT: Represents the app state before connectivity has been determined.
///
/// WHY: Prevents UI from showing incorrect status during initialization.
/// Allows loading indicators or neutral state display.
///
/// WHEN: Set when ConnectivityCubit is first created, before startMonitoring()
/// is called.
class ConnectivityInitial extends ConnectivityState {
  const ConnectivityInitial();
}

/// State representing online connectivity with sync information.
///
/// WHAT: Device is connected to the internet with optional pending operations.
///
/// WHY: Shows user both connectivity status AND if there are queued operations
/// waiting to sync. Helps manage user expectations about data freshness.
///
/// PROPERTIES:
/// - pendingCount: Number of operations waiting to be synchronized to backend
///   - 0: Fully synced, all local changes pushed
///   - >0: Some operations queued (maybe from previous offline period)
///
/// USAGE:
/// ```dart
/// if (state is ConnectivityOnline) {
///   if (state.pendingCount > 0) {
///     // Show "Syncing X items..."
///   } else {
///     // Show "All synced"
///   }
/// }
/// ```
class ConnectivityOnline extends ConnectivityState {
  final int pendingCount;

  const ConnectivityOnline({this.pendingCount = 0});

  @override
  List<Object?> get props => [pendingCount];
}

/// State representing offline connectivity with queued operations.
///
/// WHAT: Device has no internet connection, operations are being queued locally.
///
/// WHY: Informs user that they can continue working but changes won't sync
/// until connection is restored. Shows how many operations are waiting.
///
/// PROPERTIES:
/// - pendingCount: Number of operations queued for sync when online
///   - Includes CREATE, UPDATE, DELETE operations from all features
///   - Each operation represents a user action waiting to reach backend
///
/// BEHAVIOR:
/// - User can still interact with app (offline-first architecture)
/// - All mutations are queued in local database
/// - Auto-sync triggers when connectivity is restored
///
/// USAGE:
/// ```dart
/// if (state is ConnectivityOffline) {
///   // Show banner: "You're offline. X changes will sync when connected."
/// }
/// ```
class ConnectivityOffline extends ConnectivityState {
  final int pendingCount;

  const ConnectivityOffline({this.pendingCount = 0});

  @override
  List<Object?> get props => [pendingCount];
}

/// State representing active synchronization in progress.
///
/// WHAT: Device is online and actively syncing queued operations to backend.
///
/// WHY: Provides visual feedback during sync to show progress and prevent
/// user confusion. Indicates system is working to reconcile local/remote state.
///
/// PROPERTIES:
/// - pendingCount: Number of operations remaining to sync
///   - Decreases as operations complete successfully
///   - May include failed operations being retried
///
/// LIFECYCLE:
/// 1. Triggered when ConnectivityService.checkAndSync() returns true
/// 2. Shown while SyncService processes queue
/// 3. Transitions to:
///    - ConnectivityOnline(pendingCount: 0) on complete success
///    - ConnectivityOnline(pendingCount: N) if some operations remain/fail
///    - ConnectivityOffline if connection lost during sync
///
/// USAGE:
/// ```dart
/// if (state is ConnectivitySyncing) {
///   // Show: "Syncing X items..." with spinner
/// }
/// ```
class ConnectivitySyncing extends ConnectivityState {
  final int pendingCount;

  const ConnectivitySyncing({this.pendingCount = 0});

  @override
  List<Object?> get props => [pendingCount];
}
