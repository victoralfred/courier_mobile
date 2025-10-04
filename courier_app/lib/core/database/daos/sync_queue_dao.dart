part of '../app_database.dart';

/// WHAT: Data Access Object (DAO) for Sync Queue table operations
///
/// WHY: Manages the offline operation queue, enabling offline-first architecture by tracking
/// all pending database writes that need to be synchronized with the backend server. Critical
/// for maintaining data consistency between local database and remote server.
///
/// RESPONSIBILITIES:
/// - Queue management (add, get, delete operations)
/// - Operation status tracking (pending, syncing, completed, failed)
/// - Retry logic for failed sync attempts
/// - Automatic cleanup of completed operations
/// - Sync statistics and monitoring
///
/// QUERY PATTERNS:
/// - addToQueue(): Queue new operation for sync
/// - getPendingOperations(): Get all pending operations (FIFO order)
/// - getOperationsByEntity(): Filter operations for specific entity
/// - markAsSyncing/Completed/Failed(): Update operation status
/// - retryOperation(): Reset failed operation to pending
/// - deleteCompletedOperations(): Cleanup old completed operations
/// - watchPendingCount(): Real-time count of pending operations
///
/// USAGE:
/// ```dart
/// // Queue operation when creating order offline
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
/// // Sync service processes queue when online
/// final pending = await database.syncQueueDao.getPendingOperations();
/// for (final op in pending) {
///   // Mark as syncing
///   await database.syncQueueDao.markAsSyncing(op.id);
///
///   try {
///     // Parse payload and make API call
///     final payload = jsonDecode(op.payload);
///     final response = await api.request(
///       method: payload['endpoint'].split(' ')[0],
///       path: payload['endpoint'].split(' ')[1],
///       data: payload['data'],
///     );
///
///     // Mark as completed
///     await database.syncQueueDao.markAsCompleted(op.id);
///
///     // Update local entity with synced data
///     await database.orderDao.markAsSynced(op.entityId);
///   } catch (e) {
///     // Mark as failed with error message
///     await database.syncQueueDao.markAsFailed(
///       queueId: op.id,
///       error: e.toString(),
///     );
///   }
/// }
///
/// // Retry failed operations
/// final failed = await database.syncQueueDao.getPendingOperations()
///   .where((op) => op.status == 'failed' && op.retryCount < 3);
/// for (final op in failed) {
///   await database.syncQueueDao.retryOperation(op.id);
/// }
///
/// // Cleanup old completed operations (maintenance task)
/// await database.syncQueueDao.deleteCompletedOperations(olderThanDays: 7);
///
/// // Monitor sync queue in UI
/// database.syncQueueDao.watchPendingCount().listen((count) {
///   // Show sync indicator badge with pending count
/// });
/// ```
///
/// OPERATION LIFECYCLE:
/// ```
/// addToQueue() -> pending
///                   |
///                   v
/// markAsSyncing() -> syncing
///                     |
///         +-----------+-----------+
///         v                       v
/// markAsCompleted()      markAsFailed()
///         |                       |
///         v                       v
///    completed                 failed
///         |                       |
///         v                       v
/// deleteCompleted()      retryOperation()
///                                |
///                                v
///                            pending
/// ```
///
/// RETRY STRATEGY:
/// - retryCount increments on each failure
/// - lastError stores exception message for debugging
/// - Consider max retry limit (e.g., 3) to prevent infinite loops
/// - Failed operations can be manually retried or auto-retried with backoff
///
/// CLEANUP STRATEGY:
/// - Completed operations deleted after 7 days (configurable)
/// - Failed operations kept indefinitely for manual inspection
/// - Consider adding max age for failed operations
///
/// IMPROVEMENT OPPORTUNITIES:
/// - [HIGH] Implement exponential backoff for retry attempts
/// - [MEDIUM] Add priority field to process critical operations first
/// - [HIGH] Add batch processing to sync multiple operations in one API call
/// - [MEDIUM] Add maxRetries field to prevent infinite retry loops
/// - [LOW] Add syncedAt timestamp to track when operation completed
/// - [MEDIUM] Add conflict resolution for concurrent updates (optimistic locking)
/// - [HIGH] Add operation dependencies (e.g., create order before update status)
@DriftAccessor(tables: [SyncQueueTable])
class SyncQueueDao extends DatabaseAccessor<AppDatabase>
    with _$SyncQueueDaoMixin {
  SyncQueueDao(super.db);

  /// Add operation to sync queue
  Future<int> addToQueue({
    required String entityType,
    required String entityId,
    required String operation,
    required String payload,
  }) async =>
      into(syncQueueTable).insert(
        SyncQueueTableCompanion.insert(
          entityType: entityType,
          entityId: entityId,
          operation: operation,
          payload: payload,
          status: 'pending',
          createdAt: DateTime.now(),
        ),
      );

  /// Get all pending operations
  Future<List<SyncQueueTableData>> getPendingOperations() async =>
      (select(syncQueueTable)
            ..where((q) => q.status.equals('pending'))
            ..orderBy([(q) => OrderingTerm.asc(q.createdAt)]))
          .get();

  /// Get operations by entity
  Future<List<SyncQueueTableData>> getOperationsByEntity({
    required String entityType,
    required String entityId,
  }) async =>
      (select(syncQueueTable)
            ..where((q) => q.entityType.equals(entityType))
            ..where((q) => q.entityId.equals(entityId))
            ..orderBy([(q) => OrderingTerm.asc(q.createdAt)]))
          .get();

  /// Mark operation as syncing
  Future<void> markAsSyncing(int queueId) async {
    await (update(syncQueueTable)..where((q) => q.id.equals(queueId))).write(
      SyncQueueTableCompanion(
        status: const Value('syncing'),
        lastAttemptAt: Value(DateTime.now()),
      ),
    );
  }

  /// Mark operation as completed
  Future<void> markAsCompleted(int queueId) async {
    await (update(syncQueueTable)..where((q) => q.id.equals(queueId))).write(
      SyncQueueTableCompanion(
        status: const Value('completed'),
        completedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Mark operation as failed
  Future<void> markAsFailed({
    required int queueId,
    required String error,
  }) async {
    final current = await (select(syncQueueTable)
          ..where((q) => q.id.equals(queueId)))
        .getSingleOrNull();

    if (current == null) return;

    await (update(syncQueueTable)..where((q) => q.id.equals(queueId))).write(
      SyncQueueTableCompanion(
        status: const Value('failed'),
        retryCount: Value(current.retryCount + 1),
        lastError: Value(error),
        lastAttemptAt: Value(DateTime.now()),
      ),
    );
  }

  /// Retry failed operation (reset to pending)
  Future<void> retryOperation(int queueId) async {
    await (update(syncQueueTable)..where((q) => q.id.equals(queueId))).write(
      const SyncQueueTableCompanion(
        status: Value('pending'),
        lastError: Value(null),
      ),
    );
  }

  /// Delete completed operations older than specified days
  Future<int> deleteCompletedOperations({int olderThanDays = 7}) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: olderThanDays));

    return (delete(syncQueueTable)
          ..where((q) => q.status.equals('completed'))
          ..where((q) => q.completedAt.isSmallerThanValue(cutoffDate)))
        .go();
  }

  /// Delete operation
  Future<int> deleteOperation(int queueId) async =>
      (delete(syncQueueTable)..where((q) => q.id.equals(queueId))).go();

  /// Clear all operations
  Future<int> clearQueue() async => delete(syncQueueTable).go();

  /// Get failed operations count
  Future<int> getFailedCount() async {
    final result = await (selectOnly(syncQueueTable)
          ..addColumns([syncQueueTable.id.count()])
          ..where(syncQueueTable.status.equals('failed')))
        .getSingle();

    return result.read(syncQueueTable.id.count()) ?? 0;
  }

  /// Watch pending operations count
  Stream<List<int>> watchPendingCount() {
    final query = selectOnly(syncQueueTable)
      ..addColumns([syncQueueTable.id.count()])
      ..where(syncQueueTable.status.equals('pending'));

    return query.map((row) => row.read(syncQueueTable.id.count()) ?? 0).watch();
  }
}
