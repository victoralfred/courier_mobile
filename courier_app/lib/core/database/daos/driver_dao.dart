part of '../app_database.dart';

/// Data Access Object for Driver operations
///
/// Provides CRUD operations and queries for driver data
@DriftAccessor(tables: [DriverTable])
class DriverDao extends DatabaseAccessor<AppDatabase> with _$DriverDaoMixin {
  DriverDao(super.db);

  /// Get driver by ID
  Future<DriverTableData?> getDriverById(String id) async =>
      (select(driverTable)..where((d) => d.id.equals(id))).getSingleOrNull();

  /// Get driver by user ID
  Future<DriverTableData?> getDriverByUserId(String userId) async =>
      (select(driverTable)..where((d) => d.userId.equals(userId)))
          .getSingleOrNull();

  /// Insert or update driver
  Future<void> upsertDriver(DriverTableData driver) async {
    await into(driverTable).insertOnConflictUpdate(driver);
  }

  /// Update driver status
  Future<void> updateStatus(String driverId, String status) async {
    await (update(driverTable)..where((d) => d.id.equals(driverId))).write(
      DriverTableCompanion(
        status: Value(status),
      ),
    );
  }

  /// Update driver availability
  Future<void> updateAvailability(String driverId, String availability) async {
    await (update(driverTable)..where((d) => d.id.equals(driverId))).write(
      DriverTableCompanion(
        availability: Value(availability),
      ),
    );
  }

  /// Update driver location
  Future<void> updateLocation({
    required String driverId,
    required double latitude,
    required double longitude,
  }) async {
    await (update(driverTable)..where((d) => d.id.equals(driverId))).write(
      DriverTableCompanion(
        currentLatitude: Value(latitude),
        currentLongitude: Value(longitude),
        lastLocationUpdate: Value(DateTime.now()),
      ),
    );
  }

  /// Clear driver location (when going offline)
  Future<void> clearLocation(String driverId) async {
    await (update(driverTable)..where((d) => d.id.equals(driverId))).write(
      const DriverTableCompanion(
        currentLatitude: Value(null),
        currentLongitude: Value(null),
        lastLocationUpdate: Value(null),
      ),
    );
  }

  /// Update driver rating
  Future<void> updateRating({
    required String driverId,
    required double rating,
    required int totalRatings,
  }) async {
    await (update(driverTable)..where((d) => d.id.equals(driverId))).write(
      DriverTableCompanion(
        rating: Value(rating),
        totalRatings: Value(totalRatings),
      ),
    );
  }

  /// Get all available drivers (for admin/matching purposes)
  Future<List<DriverTableData>> getAvailableDrivers() async =>
      (select(driverTable)
            ..where((d) => d.availability.equals('available'))
            ..where((d) => d.status.equals('approved')))
          .get();

  /// Delete driver
  Future<int> deleteDriver(String driverId) async =>
      (delete(driverTable)..where((d) => d.id.equals(driverId))).go();

  /// Mark driver as synced
  Future<void> markAsSynced(String driverId) async {
    await (update(driverTable)..where((d) => d.id.equals(driverId))).write(
      DriverTableCompanion(
        lastSyncedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Update driver ID and status after backend sync
  /// Used when a local driver is synced to backend and we get back the server-generated ID
  Future<void> updateDriverIdAndStatus({
    required String localId,
    required String backendId,
    required String status,
  }) async {
    final driver = await getDriverById(localId);
    if (driver != null) {
      // Delete old record with local ID
      await deleteDriver(localId);

      // Insert new record with backend ID
      await upsertDriver(driver.copyWith(
        id: backendId,
        status: status,
        lastSyncedAt: Value(DateTime.now()),
      ));
    }
  }

  /// Watch driver by ID for realtime updates
  Stream<DriverTableData?> watchDriverById(String id) =>
      (select(driverTable)..where((d) => d.id.equals(id))).watchSingleOrNull();

  /// Watch driver by user ID for realtime updates
  Stream<DriverTableData?> watchDriverByUserId(String userId) =>
      (select(driverTable)..where((d) => d.userId.equals(userId)))
          .watchSingleOrNull();
}
