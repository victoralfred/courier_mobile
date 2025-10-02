part of '../app_database.dart';

/// Data Access Object for Sync Queue operations
///
/// Manages offline operation queue for syncing with backend
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
