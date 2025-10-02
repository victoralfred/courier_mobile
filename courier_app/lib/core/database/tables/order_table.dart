part of '../app_database.dart';

/// Order table for storing delivery orders
///
/// Stores order information with pickup/dropoff locations and status
@DataClassName('OrderTableData')
class OrderTable extends Table {
  @override
  String get tableName => 'orders';

  /// Unique order ID
  TextColumn get id => text()();

  /// Customer user ID
  TextColumn get userId => text()();

  /// Assigned driver ID (nullable before assignment)
  TextColumn get driverId => text().nullable()();

  // Pickup Location
  /// Pickup address
  TextColumn get pickupAddress => text()();

  /// Pickup latitude
  RealColumn get pickupLatitude => real()();

  /// Pickup longitude
  RealColumn get pickupLongitude => real()();

  /// Pickup city
  TextColumn get pickupCity => text()();

  /// Pickup state
  TextColumn get pickupState => text()();

  /// Pickup postcode (nullable)
  TextColumn get pickupPostcode => text().nullable()();

  // Dropoff Location
  /// Dropoff address
  TextColumn get dropoffAddress => text()();

  /// Dropoff latitude
  RealColumn get dropoffLatitude => real()();

  /// Dropoff longitude
  RealColumn get dropoffLongitude => real()();

  /// Dropoff city
  TextColumn get dropoffCity => text()();

  /// Dropoff state
  TextColumn get dropoffState => text()();

  /// Dropoff postcode (nullable)
  TextColumn get dropoffPostcode => text().nullable()();

  // Price
  /// Price amount in Naira
  RealColumn get priceAmount => real()();

  // Status
  /// Order status: 'pending', 'assigned', 'pickup', 'in_transit', 'completed', 'cancelled'
  TextColumn get status => text()();

  // Timestamps
  /// Pickup started timestamp
  DateTimeColumn get pickupStartedAt => dateTime().nullable()();

  /// Pickup completed timestamp
  DateTimeColumn get pickupCompletedAt => dateTime().nullable()();

  /// Order completed timestamp
  DateTimeColumn get completedAt => dateTime().nullable()();

  /// Order cancelled timestamp
  DateTimeColumn get cancelledAt => dateTime().nullable()();

  /// Order creation timestamp
  DateTimeColumn get createdAt => dateTime()();

  /// Last update timestamp
  DateTimeColumn get updatedAt => dateTime()();

  /// Last sync with backend
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// OrderItem table for storing package details
///
/// One-to-one relationship with Order
@DataClassName('OrderItemTableData')
class OrderItemTable extends Table {
  @override
  String get tableName => 'order_items';

  /// Order ID (foreign key to orders table)
  TextColumn get orderId => text()();

  /// Package category
  TextColumn get category => text()();

  /// Package description
  TextColumn get description => text()();

  /// Package weight in kilograms
  RealColumn get weight => real()();

  /// Package size: 'small', 'medium', 'large', 'xlarge'
  TextColumn get size => text()();

  @override
  Set<Column> get primaryKey => {orderId};
}
