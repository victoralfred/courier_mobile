part of '../app_database.dart';

/// WHAT: Driver table schema for storing driver profiles and vehicle information
///
/// WHY: Stores driver onboarding data, verification status, vehicle details, and real-time
/// location/availability. Supports driver lifecycle from pending approval to active delivery.
/// Critical for driver matching, order assignment, and fleet management.
///
/// TABLE SCHEMA:
/// ```sql
/// CREATE TABLE drivers (
///   id TEXT PRIMARY KEY,                    -- Server-generated UUID
///   userId TEXT UNIQUE NOT NULL,            -- FK to users.id (one driver per user)
///   firstName TEXT NOT NULL,
///   lastName TEXT NOT NULL,
///   email TEXT NOT NULL,
///   phone TEXT NOT NULL,
///   licenseNumber TEXT NOT NULL,            -- Driver's license number
///
///   -- Vehicle Information
///   vehiclePlate TEXT NOT NULL,
///   vehicleType TEXT NOT NULL,              -- 'motorcycle'|'car'|'van'|'bicycle'
///   vehicleMake TEXT NOT NULL,
///   vehicleModel TEXT NOT NULL,
///   vehicleYear INTEGER NOT NULL,
///   vehicleColor TEXT NOT NULL,
///
///   -- Status and Availability
///   status TEXT NOT NULL,                   -- 'pending'|'approved'|'rejected'|'suspended'
///   availability TEXT NOT NULL,             -- 'offline'|'available'|'busy'
///
///   -- Real-time Location (nullable when offline)
///   currentLatitude REAL,                   -- Nigeria bounds: 4-14°N
///   currentLongitude REAL,                  -- Nigeria bounds: 3-15°E
///   lastLocationUpdate DATETIME,
///
///   -- Rating System
///   rating REAL NOT NULL DEFAULT 0.0,       -- Average rating (0-5)
///   totalRatings INTEGER NOT NULL DEFAULT 0,
///
///   -- Status Tracking (v2+)
///   rejectionReason TEXT,                   -- Why application was rejected
///   suspensionReason TEXT,                  -- Why account was suspended
///   suspensionExpiresAt DATETIME,           -- When suspension ends (null = permanent)
///   statusUpdatedAt DATETIME,               -- Last status change timestamp
///
///   lastSyncedAt DATETIME
/// );
/// CREATE UNIQUE INDEX idx_drivers_userId ON drivers(userId);
/// ```
///
/// RELATIONSHIPS:
/// - N:1 with users (many drivers can reference one user, but UNIQUE constraint enforces 1:1)
/// - 1:N with orders (one driver can be assigned many orders)
///
/// INDEXES:
/// - PRIMARY KEY on id
/// - UNIQUE index on userId (enforces one driver per user)
/// - Consider adding composite index on (status, availability) for driver matching
///
/// STATUS WORKFLOW:
/// ```
/// pending -> approved -> [available|offline]
///    |          |
///    v          v
/// rejected   suspended -> approved (after expiry)
/// ```
///
/// USAGE:
/// ```dart
/// // Create driver profile during onboarding
/// final driver = DriverTableCompanion.insert(
///   id: 'local-uuid',  // Replaced with server ID after sync
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
///
/// // Update location when driver goes online
/// await database.driverDao.updateLocation(
///   driverId: driver.id,
///   latitude: 6.5244,
///   longitude: 3.3792,
/// );
/// ```
///
/// DATA LIFECYCLE:
/// - Created: During driver onboarding flow
/// - Updated: Status changes, location updates, rating updates
/// - Deleted: When driver account is permanently deleted
/// - Synced: After approval/rejection, on availability changes
///
/// IMPROVEMENT OPPORTUNITIES:
/// - [HIGH] Add composite index on (status, availability) for faster driver matching
/// - [MEDIUM] Add documentsVerified JSON field to track document verification status
/// - [LOW] Add totalDeliveries counter for driver statistics
/// - [MEDIUM] Consider spatial index on (currentLatitude, currentLongitude) for proximity searches
/// - [LOW] Add vehicleCapacity field for large item deliveries
/// - [HIGH] Add lastActiveAt timestamp to identify inactive drivers
@DataClassName('DriverTableData')
class DriverTable extends Table {
  @override
  String get tableName => 'drivers';

  /// Unique driver ID
  TextColumn get id => text()();

  /// Associated user ID (unique - one driver per user)
  TextColumn get userId => text().unique()();

  /// Driver's first name
  TextColumn get firstName => text()();

  /// Driver's last name
  TextColumn get lastName => text()();

  /// Driver's email
  TextColumn get email => text()();

  /// Driver's phone number
  TextColumn get phone => text()();

  /// Driver's license number
  TextColumn get licenseNumber => text()();

  // Vehicle Information
  /// Vehicle plate number
  TextColumn get vehiclePlate => text()();

  /// Vehicle type: 'motorcycle', 'car', 'van', 'bicycle'
  TextColumn get vehicleType => text()();

  /// Vehicle make (e.g., 'Toyota')
  TextColumn get vehicleMake => text()();

  /// Vehicle model (e.g., 'Corolla')
  TextColumn get vehicleModel => text()();

  /// Vehicle year
  IntColumn get vehicleYear => integer()();

  /// Vehicle color
  TextColumn get vehicleColor => text()();

  // Status and Availability
  /// Driver status: 'pending', 'approved', 'rejected', 'suspended'
  TextColumn get status => text()();

  /// Availability: 'offline', 'available', 'busy'
  TextColumn get availability => text()();

  // Location (nullable - only set when driver is online)
  /// Current latitude (Nigeria bounds: 4-14°N)
  RealColumn get currentLatitude => real().nullable()();

  /// Current longitude (Nigeria bounds: 3-15°E)
  RealColumn get currentLongitude => real().nullable()();

  /// Last location update timestamp
  DateTimeColumn get lastLocationUpdate => dateTime().nullable()();

  // Rating
  /// Average rating (0-5)
  RealColumn get rating => real()();

  /// Total number of ratings received
  IntColumn get totalRatings => integer()();

  // Status tracking fields
  /// Reason why driver application was rejected (null if not rejected)
  TextColumn get rejectionReason => text().nullable()();

  /// Reason why driver account was suspended (null if not suspended)
  TextColumn get suspensionReason => text().nullable()();

  /// Date when suspension expires (null if not suspended or permanent)
  DateTimeColumn get suspensionExpiresAt => dateTime().nullable()();

  /// Timestamp when driver status was last updated
  DateTimeColumn get statusUpdatedAt => dateTime().nullable()();

  /// Last sync with backend
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
