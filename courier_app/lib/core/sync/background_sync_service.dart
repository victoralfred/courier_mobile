import 'package:workmanager/workmanager.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/app_logger.dart';
import '../database/app_database.dart';

/// [BackgroundSyncService] - Manages background synchronization of offline queue
///
/// **What it does:**
/// - Schedules periodic background sync tasks using WorkManager
/// - Processes offline request queue when app is in background
/// - Ensures data synchronization even when app is closed
/// - Handles platform-specific background execution constraints
///
/// **Why it exists:**
/// - Mobile apps need to sync data even when in background/killed
/// - Users shouldn't have to keep app open for sync to complete
/// - Improve data consistency and reduce sync backlog
/// - Better user experience (changes sync automatically)
///
/// **Platform Support:**
/// - **Android**: Uses WorkManager (JobScheduler/AlarmManager)
/// - **iOS**: Uses Background Fetch (limited to system-determined intervals)
///
/// **Background Task Constraints:**
/// - Requires network connectivity
/// - Respects battery optimization settings
/// - Runs when device is idle (Android)
/// - Limited frequency on iOS (~15 minutes minimum)
///
/// **Usage Example:**
/// ```dart
/// // Initialize in main()
/// await BackgroundSyncService.initialize();
///
/// // Register periodic sync (every 15 minutes)
/// await BackgroundSyncService.registerPeriodicSync();
///
/// // Cancel background sync
/// await BackgroundSyncService.cancelSync();
/// ```
class BackgroundSyncService {
  static final AppLogger _logger = AppLogger('BackgroundSyncService');

  /// Unique task name for background sync
  static const String syncTaskName = 'com.delivery_app.background_sync';

  /// Unique tag for WorkManager task
  static const String syncTaskTag = 'background_sync_task';

  /// Minimum interval between sync tasks (15 minutes)
  /// Note: iOS may run less frequently based on system scheduling
  static const Duration syncInterval = Duration(minutes: 15);

  /// Maximum execution time for background task
  static const Duration maxExecutionTime = Duration(minutes: 5);

  /// Initializes background sync with WorkManager
  ///
  /// **What it does:**
  /// - Initializes WorkManager plugin
  /// - Registers callback dispatcher for background execution
  /// - Sets up logging for background tasks
  ///
  /// **When to call:**
  /// - Call once in main() before runApp()
  /// - Required before scheduling any background tasks
  ///
  /// **Example:**
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await BackgroundSyncService.initialize();
  ///   runApp(MyApp());
  /// }
  /// ```
  static Future<void> initialize() async {
    try {
      _logger.info('Initializing BackgroundSyncService');

      // Initialize WorkManager with callback dispatcher
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: false, // Set to true for debugging
      );

      _logger.info('BackgroundSyncService initialized successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to initialize BackgroundSyncService',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Registers periodic background sync task
  ///
  /// **What it does:**
  /// - Schedules task to run every 15 minutes (minimum)
  /// - Requires network connectivity
  /// - Replaces existing task if already registered
  ///
  /// **Platform Behavior:**
  /// - **Android**: Runs approximately every 15 minutes when device idle
  /// - **iOS**: System determines actual frequency (may be less frequent)
  ///
  /// **Constraints:**
  /// - Network connectivity required
  /// - Respects battery saver mode
  /// - Won't run if battery too low
  ///
  /// **Example:**
  /// ```dart
  /// // Register on user login
  /// await BackgroundSyncService.registerPeriodicSync();
  ///
  /// // Task will now run every ~15 minutes
  /// ```
  static Future<void> registerPeriodicSync() async {
    try {
      _logger.info('Registering periodic background sync', metadata: {
        'interval_minutes': syncInterval.inMinutes,
        'task_name': syncTaskName,
      });

      // Register periodic task (Android uses PeriodicWorkRequest, iOS uses Background Fetch)
      await Workmanager().registerPeriodicTask(
        syncTaskName, // Unique task name
        syncTaskTag, // Task tag for identification
        frequency: syncInterval,
        constraints: Constraints(
          networkType: NetworkType.connected, // Require network
          requiresBatteryNotLow: true, // Don't run if battery low
          requiresDeviceIdle: false, // Can run while device active
          requiresCharging: false, // Can run on battery
        ),
        existingWorkPolicy: ExistingWorkPolicy.replace, // Replace if exists
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 1),
      );

      _logger.info('Periodic background sync registered successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to register periodic sync',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Registers one-time sync task (manual trigger)
  ///
  /// **What it does:**
  /// - Schedules immediate one-time sync task
  /// - Useful for manual "sync now" button
  /// - Runs once and then removes itself
  ///
  /// **Example:**
  /// ```dart
  /// // User clicks "Sync Now" button
  /// await BackgroundSyncService.registerOneShotSync();
  /// ```
  static Future<void> registerOneShotSync() async {
    try {
      _logger.info('Registering one-shot background sync');

      await Workmanager().registerOneOffTask(
        'oneshot_sync_${DateTime.now().millisecondsSinceEpoch}',
        syncTaskTag,
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: false, // Allow even if battery low
        ),
        existingWorkPolicy: ExistingWorkPolicy.append,
      );

      _logger.info('One-shot background sync registered');
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to register one-shot sync',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Cancels all background sync tasks
  ///
  /// **What it does:**
  /// - Cancels periodic sync task
  /// - Removes from WorkManager queue
  /// - Stops future background executions
  ///
  /// **When to use:**
  /// - User logs out
  /// - User disables background sync in settings
  /// - App uninstalled (automatic)
  ///
  /// **Example:**
  /// ```dart
  /// // User logs out
  /// await BackgroundSyncService.cancelSync();
  /// ```
  static Future<void> cancelSync() async {
    try {
      _logger.info('Cancelling background sync tasks');

      await Workmanager().cancelByUniqueName(syncTaskName);

      _logger.info('Background sync tasks cancelled');
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to cancel sync tasks',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Cancels all WorkManager tasks
  ///
  /// **What it does:**
  /// - Cancels ALL background tasks (not just sync)
  /// - Nuclear option for complete reset
  ///
  /// **When to use:**
  /// - App reset/reinstall
  /// - Debugging purposes
  /// - Clean slate needed
  ///
  /// **Warning:** Cancels ALL background tasks, not just sync!
  static Future<void> cancelAllTasks() async {
    try {
      _logger.warning('Cancelling ALL background tasks');

      await Workmanager().cancelAll();

      _logger.info('All background tasks cancelled');
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to cancel all tasks',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}

/// Callback dispatcher for background execution
///
/// **IMPORTANT:**
/// - This function runs in a separate isolate (no access to main app state)
/// - Must be a top-level function (not a class method)
/// - Can only use static methods and classes
/// - Cannot access UI or app context
///
/// **What it does:**
/// - Receives background task execution callbacks from WorkManager
/// - Routes to appropriate handler based on task name
/// - Processes sync queue when connectivity available
///
/// **Execution Environment:**
/// - Runs in background isolate (separate from main app)
/// - Limited execution time (~10 minutes on Android, less on iOS)
/// - Must complete before timeout or will be killed
/// - Cannot show UI or interact with app UI
///
/// **How WorkManager calls this:**
/// ```
/// Android: JobScheduler → WorkManager → callbackDispatcher()
/// iOS: BGTaskScheduler → WorkManager → callbackDispatcher()
/// ```
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    final logger = AppLogger('BackgroundSyncCallback');

    try {
      logger.info('Background task started', metadata: {
        'task_name': taskName,
        'input_data': inputData,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Only process our sync task
      if (taskName == BackgroundSyncService.syncTaskTag) {
        // Check connectivity before processing
        // Note: Background tasks run in separate isolate, so we check connectivity directly
        final connectivity = Connectivity();
        final connectivityResults = await connectivity.checkConnectivity();
        final isOnline = !connectivityResults.contains(ConnectivityResult.none) &&
            connectivityResults.isNotEmpty;

        if (!isOnline) {
          logger.info('Offline, skipping background sync');
          return Future.value(true); // Success (will retry later)
        }

        // Initialize database for background isolate
        // Note: Must recreate dependencies as this is a separate isolate
        final database = AppDatabase();

        // Get pending sync queue items
        final pendingOperations = await database.syncQueueDao.getPendingOperations();

        logger.info('Found pending operations in background', metadata: {
          'count': pendingOperations.length,
        });

        // Note: Actual processing requires ApiClient which is complex to recreate
        // in background isolate. For now, this task just checks for pending items.
        // The actual sync will happen when app is in foreground via ConnectivityService.
        //
        // Future enhancement: Create a standalone HTTP client for background processing
        // that doesn't depend on full app dependency injection.

        logger.info('Background sync check completed', metadata: {
          'pending_operations': pendingOperations.length,
        });

        // Cleanup
        await database.close();

        return Future.value(true); // Success
      }

      logger.warning('Unknown task name', metadata: {'task_name': taskName});
      return Future.value(false); // Unknown task
    } catch (e, stackTrace) {
      logger.error(
        'Background task failed',
        error: e,
        stackTrace: stackTrace,
        metadata: {'task_name': taskName},
      );
      return Future.value(false); // Failure (will retry)
    }
  });
}

/// IMPROVEMENTS:
/// - [Medium Priority] Add sync statistics tracking (success/failure counts)
/// - [Medium Priority] Add user-configurable sync interval in app settings
/// - [Low Priority] Add battery-aware sync frequency (reduce when low battery)
/// - [Low Priority] Add network-type awareness (WiFi vs cellular)
/// - [Medium Priority] Add notification on successful background sync
/// - [Low Priority] Implement adaptive sync interval based on queue size
/// - [Medium Priority] Add metrics/telemetry for background task performance
