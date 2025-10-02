part of '../app_database.dart';

/// Sync queue table for tracking offline operations
///
/// Stores pending operations to be synced when connection is restored
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
