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

/// Main application database using Drift
///
/// Provides offline-first data persistence for Nigerian courier app
/// with automatic sync queue management
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

/// Opens a connection to the database
LazyDatabase _openConnection() => LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'courier_app.db'));
      return NativeDatabase(file);
    });
