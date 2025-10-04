part of '../app_database.dart';

/// WHAT: Sync queue table for offline operation tracking and synchronization
///
/// WHY: Enables offline-first architecture by queuing all write operations (create, update, delete)
/// when network is unavailable. Operations are processed in order when connection is restored,
/// ensuring data consistency between local database and backend server.
///
/// TABLE SCHEMA:
/// ```sql
/// CREATE TABLE sync_queue (
///   id INTEGER PRIMARY KEY AUTOINCREMENT,   -- Auto-incrementing queue ID
///   entityType TEXT NOT NULL,               -- 'user'|'driver'|'order'
///   entityId TEXT NOT NULL,                 -- ID of the entity being synced
///   operation TEXT NOT NULL,                -- 'create'|'update'|'delete'|'update_status'|'assign_driver'
///   payload TEXT NOT NULL,                  -- JSON payload containing endpoint and data
///   status TEXT NOT NULL,                   -- 'pending'|'syncing'|'completed'|'failed'
///   retryCount INTEGER NOT NULL DEFAULT 0,  -- Number of retry attempts
///   lastError TEXT,                         -- Last error message (for debugging)
///   createdAt DATETIME NOT NULL,            -- When operation was queued
///   lastAttemptAt DATETIME,                 -- Last sync attempt timestamp
///   completedAt DATETIME                    -- When sync completed successfully
/// );
/// CREATE INDEX idx_sync_queue_status ON sync_queue(status);
/// CREATE INDEX idx_sync_queue_entity ON sync_queue(entityType, entityId);
/// ```
///
/// RELATIONSHIPS:
/// - Standalone table (references entities by ID but no foreign key constraints)
/// - Loosely coupled to all entity tables (users, drivers, orders)
///
/// INDEXES:
/// - PRIMARY KEY on id (auto-increment ensures FIFO order)
/// - Index on status for filtering pending/failed operations
/// - Composite index on (entityType, entityId) for entity-specific queries
///
/// STATUS WORKFLOW:
/// ```
/// pending -> syncing -> completed (success)
///              |
///              v
///            failed -> pending (retry)
/// ```
///
/// PAYLOAD STRUCTURE:
/// ```json
/// {
///   "endpoint": "POST /orders",
///   "data": {
///     "pickupLocation": {...},
///     "dropoffLocation": {...},
///     "item": {...}
///   }
/// }
/// ```
///
/// USAGE:
/// ```dart
/// // Queue operation when offline
/// await database.syncQueueDao.addToQueue(
///   entityType: 'order',
///   entityId: order.id,
///   operation: 'create',
///   payload: jsonEncode({
///     'endpoint': 'POST /orders',
///     'data': orderData.toCreateJson(item: itemData),
///   }),
/// );
///
/// // Process pending operations when online
/// final pending = await database.syncQueueDao.getPendingOperations();
/// for (final op in pending) {
///   await database.syncQueueDao.markAsSyncing(op.id);
///   try {
///     // Sync with backend...
///     await database.syncQueueDao.markAsCompleted(op.id);
///   } catch (e) {
///     await database.syncQueueDao.markAsFailed(
///       queueId: op.id,
///       error: e.toString(),
///     );
///   }
/// }
/// ```
///
/// DATA LIFECYCLE:
/// - Created: When any write operation occurs offline or needs tracking
/// - Updated: Status changes during sync process
/// - Deleted: After successful completion (cleaned up periodically)
/// - Auto-cleanup: Completed operations older than 7 days
///
/// RETRY STRATEGY:
/// - Failed operations remain in queue for manual retry or auto-retry
/// - retryCount tracks number of attempts (consider max retry limit)
/// - lastError helps diagnose persistent failures
///
/// IMPROVEMENT OPPORTUNITIES:
/// - [HIGH] Implement exponential backoff for retry attempts
/// - [MEDIUM] Add maxRetries limit to prevent infinite retry loops
/// - [HIGH] Add priority field for critical operations (e.g., order creation vs. profile update)
/// - [MEDIUM] Add batch sync support to reduce API calls
/// - [LOW] Add sync statistics (total synced, failed, pending counts)
/// - [MEDIUM] Implement conflict resolution strategy for concurrent updates
@DataClassName('SyncQueueTableData')
class SyncQueueTable extends Table {
  @override
  String get tableName => 'sync_queue';

  /// Auto-incrementing ID
  IntColumn get id => integer().autoIncrement()();

  /// Entity type: 'user', 'driver', 'order'
  TextColumn get entityType => text()();

  /// Entity ID
  TextColumn get entityId => text()();

  /// Operation type: 'create', 'update', 'delete'
  TextColumn get operation => text()();

  /// JSON payload of the operation
  TextColumn get payload => text()();

  /// Sync status: 'pending', 'syncing', 'completed', 'failed'
  TextColumn get status => text()();

  /// Number of retry attempts
  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  /// Last error message (nullable)
  TextColumn get lastError => text().nullable()();

  /// Operation created timestamp
  DateTimeColumn get createdAt => dateTime()();

  /// Last attempt timestamp
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();

  /// Completed timestamp
  DateTimeColumn get completedAt => dateTime().nullable()();
}
