part of '../app_database.dart';

/// Driver table for storing driver information
///
/// Stores driver details, vehicle info, status, and real-time availability
@DataClassName('DriverTableData')
class DriverTable extends Table {
  @override
  String get tableName => 'drivers';

  /// Unique driver ID
  TextColumn get id => text()();

  /// Associated user ID
  TextColumn get userId => text()();

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

  /// Last sync with backend
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
