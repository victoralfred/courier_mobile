part of '../app_database.dart';

/// WHAT: Data Access Object (DAO) for Driver table operations
///
/// WHY: Encapsulates all database operations for drivers, providing a clean API for
/// driver onboarding, status management, location tracking, and availability updates.
/// Critical for driver lifecycle management and real-time driver matching.
///
/// RESPONSIBILITIES:
/// - Driver CRUD operations (get, upsert, delete)
/// - Driver status management (pending, approved, rejected, suspended)
/// - Real-time location tracking and availability updates
/// - Driver rating and statistics management
/// - Backend ID synchronization after driver registration
/// - Real-time driver data streaming via watch methods
///
/// QUERY PATTERNS:
/// - getDriverById(): Lookup by driver ID
/// - getDriverByUserId(): Lookup by associated user (1:1 relationship)
/// - getAvailableDrivers(): Find drivers ready for order assignment
/// - updateLocation(): Track driver position for proximity matching
/// - updateDriverIdAndStatus(): Sync local driver with backend-generated ID
///
/// USAGE:
/// ```dart
/// // Driver onboarding - create local driver profile
/// final driver = DriverTableCompanion.insert(
///   id: 'local-${uuid.v4()}',  // Local ID until backend sync
///   userId: currentUser.id,
///   firstName: 'John',
///   lastName: 'Doe',
///   email: 'john@example.com',
///   phone: '+2348012345678',
///   licenseNumber: 'ABC123456',
///   vehiclePlate: 'LAG-123-AB',
///   vehicleType: 'motorcycle',
///   vehicleMake: 'Honda',
///   vehicleModel: 'CB125',
///   vehicleYear: 2020,
///   vehicleColor: 'Red',
///   status: 'pending',
///   availability: 'offline',
///   rating: 0.0,
///   totalRatings: 0,
/// );
/// await database.driverDao.upsertDriver(driver);
///
/// // After backend sync - update with server ID
/// await database.driverDao.updateDriverIdAndStatus(
///   localId: 'local-abc123',
///   backendId: 'server-xyz789',
///   status: 'pending',
/// );
///
/// // Driver goes online - update location and availability
/// await database.driverDao.updateAvailability(driver.id, 'available');
/// await database.driverDao.updateLocation(
///   driverId: driver.id,
///   latitude: 6.5244,
///   longitude: 3.3792,
/// );
///
/// // Driver goes offline - clear location
/// await database.driverDao.updateAvailability(driver.id, 'offline');
/// await database.driverDao.clearLocation(driver.id);
///
/// // Watch driver status for reactive UI
/// database.driverDao.watchDriverByUserId(userId).listen((driver) {
///   // Update UI when driver status changes
/// });
/// ```
///
/// LOCATION TRACKING:
/// - Location only stored when driver is online (available/busy)
/// - Nigeria geographic bounds: 4-14°N, 3-15°E
/// - lastLocationUpdate tracks staleness (consider timeout for inactive drivers)
///
/// STATUS TRANSITIONS:
/// - pending -> approved (admin approval)
/// - pending -> rejected (failed verification)
/// - approved -> suspended (policy violation)
/// - suspended -> approved (suspension expired or lifted)
///
/// IMPROVEMENT OPPORTUNITIES:
/// - [HIGH] Add getDriversNearLocation() for proximity-based matching
/// - [MEDIUM] Add updateRatingWithNewReview() to atomically calculate average
/// - [LOW] Add getDriverStatistics() for performance metrics
/// - [MEDIUM] Add validation for Nigeria geographic bounds on location updates
/// - [HIGH] Add stale location check (flag drivers with old lastLocationUpdate)
/// - [LOW] Add getDriversByStatus() for admin dashboard filtering
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

  /// Delete driver by ID
  Future<int> deleteDriver(String driverId) async =>
      (delete(driverTable)..where((d) => d.id.equals(driverId))).go();

  /// Delete driver by user ID
  Future<int> deleteDriverByUserId(String userId) async =>
      (delete(driverTable)..where((d) => d.userId.equals(userId))).go();

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
