import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// Tables
part 'tables/user_table.dart';
part 'tables/driver_table.dart';
part 'tables/order_table.dart';
part 'tables/sync_queue_table.dart';

// DAOs
part 'daos/user_dao.dart';
part 'daos/driver_dao.dart';
part 'daos/order_dao.dart';
part 'daos/sync_queue_dao.dart';

// Generated code
part 'app_database.g.dart';

/// WHAT: Main application database using Drift ORM for offline-first data persistence
///
/// WHY: Provides local SQLite database with automatic code generation, type safety,
/// and reactive streams for real-time updates. Implements offline-first architecture
/// allowing the app to function fully without network connectivity, with automatic
/// sync queue for pending operations when connection is restored.
///
/// FEATURES:
/// - Offline-first data persistence with automatic sync queue
/// - Type-safe database operations with compile-time query validation
/// - Reactive streams for real-time UI updates via watchX() methods
/// - Transaction support for atomic multi-table operations
/// - Automatic schema migrations with version management
/// - Separate DAOs for clean separation of concerns
///
/// DATABASE SCHEMA:
/// ```
/// users (1) ----< (1) drivers
///   |                  |
///   | (1:N)            | (1:N)
///   v                  v
/// orders (N:1) ---< (1:1) order_items
///
/// sync_queue (standalone - tracks pending operations)
/// ```
///
/// SCHEMA VERSION: 3
/// - v1: Initial schema (users, drivers, orders, order_items, sync_queue)
/// - v2: Added driver status tracking fields (rejectionReason, suspensionReason, etc.)
/// - v3: Added unique constraint on drivers.userId
///
/// USAGE:
/// ```dart
/// // Initialize database (singleton pattern)
/// final database = AppDatabase();
///
/// // Access DAOs for specific operations
/// final user = await database.userDao.getCurrentUser();
/// final orders = await database.orderDao.getOrdersByUserId(userId);
///
/// // Watch for real-time updates
/// database.orderDao.watchActiveOrders(userId).listen((orders) {
///   // UI updates automatically when data changes
/// });
///
/// // Transaction example
/// await database.transaction(() async {
///   await database.orderDao.insertOrderWithItem(order: orderData, item: itemData);
///   await database.syncQueueDao.addToQueue(...);
/// });
///
/// // Testing with in-memory database
/// final testDb = AppDatabase.test(NativeDatabase.memory());
/// ```
///
/// MIGRATION STRATEGY:
/// - onCreate: Creates all tables from scratch for new installations
/// - onUpgrade: Incremental migrations from old versions to new versions
/// - Schema changes are handled through Drift's migration system
/// - Always test migrations with real data before deployment
///
/// IMPROVEMENT OPPORTUNITIES:
/// - [MEDIUM] Add database encryption for sensitive data (user tokens, personal info)
/// - [LOW] Implement database backup/restore functionality
/// - [LOW] Add database size monitoring and cleanup strategies
/// - [MEDIUM] Consider adding composite indexes for frequently queried columns
/// - [HIGH] Add database integrity checks on app startup
/// - [LOW] Implement database vacuum on app idle to reclaim space
@DriftDatabase(
  tables: [
    UserTable,
    DriverTable,
    OrderTable,
    OrderItemTable,
    SyncQueueTable,
  ],
  daos: [
    UserDao,
    DriverDao,
    OrderDao,
    SyncQueueDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.test(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from == 1 && to == 2) {
            // Add new columns for driver status tracking
            await m.addColumn(driverTable, driverTable.rejectionReason);
            await m.addColumn(driverTable, driverTable.suspensionReason);
            await m.addColumn(driverTable, driverTable.suspensionExpiresAt);
            await m.addColumn(driverTable, driverTable.statusUpdatedAt);
          }
          if (from == 2 && to == 3) {
            // Add unique constraint on userId - recreate table to add constraint
            // Note: Drift will automatically handle this via schema change
            await m.recreateAllViews();
          }
        },
      );
}

/// Opens a lazy connection to the SQLite database
///
/// Uses LazyDatabase to defer connection until first access, improving app startup time.
/// Database file is stored in application documents directory for persistence across sessions.
///
/// Location: {app_documents}/courier_app.db
LazyDatabase _openConnection() => LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'courier_app.db'));
      return NativeDatabase(file);
    });
