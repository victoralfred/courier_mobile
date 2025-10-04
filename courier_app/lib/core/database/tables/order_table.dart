part of '../app_database.dart';

/// WHAT: Order table schema for storing delivery order information
///
/// WHY: Stores customer orders with pickup/dropoff locations, pricing, and status tracking.
/// Core entity for the delivery workflow, supporting offline order creation and real-time
/// status updates. Works in conjunction with OrderItemTable for package details.
///
/// TABLE SCHEMA:
/// ```sql
/// CREATE TABLE orders (
///   id TEXT PRIMARY KEY,                    -- Server-generated UUID
///   userId TEXT NOT NULL,                   -- FK to users.id (customer)
///   driverId TEXT,                          -- FK to drivers.id (assigned driver)
///
///   -- Pickup Location
///   pickupAddress TEXT NOT NULL,
///   pickupLatitude REAL NOT NULL,
///   pickupLongitude REAL NOT NULL,
///   pickupCity TEXT NOT NULL,
///   pickupState TEXT NOT NULL,
///   pickupPostcode TEXT,
///
///   -- Dropoff Location
///   dropoffAddress TEXT NOT NULL,
///   dropoffLatitude REAL NOT NULL,
///   dropoffLongitude REAL NOT NULL,
///   dropoffCity TEXT NOT NULL,
///   dropoffState TEXT NOT NULL,
///   dropoffPostcode TEXT,
///
///   -- Pricing
///   priceAmount REAL NOT NULL,              -- Price in Naira (NGN)
///
///   -- Status Tracking
///   status TEXT NOT NULL,                   -- 'pending'|'assigned'|'pickup'|'in_transit'|'completed'|'cancelled'
///
///   -- Timestamps
///   pickupStartedAt DATETIME,               -- When driver started pickup
///   pickupCompletedAt DATETIME,             -- When driver completed pickup
///   completedAt DATETIME,                   -- When order was delivered
///   cancelledAt DATETIME,                   -- When order was cancelled
///   createdAt DATETIME NOT NULL,
///   updatedAt DATETIME NOT NULL,
///   lastSyncedAt DATETIME
/// );
/// ```
///
/// RELATIONSHIPS:
/// - N:1 with users (many orders belong to one customer)
/// - N:1 with drivers (many orders assigned to one driver)
/// - 1:1 with order_items (one order has one package/item)
///
/// INDEXES:
/// - PRIMARY KEY on id
/// - Consider composite index on (userId, status) for customer order filtering
/// - Consider composite index on (driverId, status) for driver order filtering
/// - Consider index on status for pending orders query
///
/// STATUS WORKFLOW:
/// ```
/// pending -> assigned -> pickup -> in_transit -> completed
///    |          |          |           |
///    v          v          v           v
/// cancelled  cancelled  cancelled  cancelled
/// ```
///
/// USAGE:
/// ```dart
/// // Create new order
/// final order = OrderTableCompanion.insert(
///   id: 'uuid',
///   userId: currentUser.id,
///   pickupAddress: '123 Main St',
///   pickupLatitude: 6.5244,
///   pickupLongitude: 3.3792,
///   pickupCity: 'Lagos',
///   pickupState: 'Lagos',
///   dropoffAddress: '456 Oak Ave',
///   dropoffLatitude: 6.4281,
///   dropoffLongitude: 3.4219,
///   dropoffCity: 'Lagos',
///   dropoffState: 'Lagos',
///   priceAmount: 2500.0,
///   status: 'pending',
///   createdAt: DateTime.now(),
///   updatedAt: DateTime.now(),
/// );
///
/// // Update order status
/// await database.orderDao.updateOrderStatus(
///   orderId: order.id,
///   status: 'pickup',
///   pickupStartedAt: DateTime.now(),
/// );
/// ```
///
/// DATA LIFECYCLE:
/// - Created: When customer places order
/// - Updated: Status changes, driver assignment
/// - Deleted: Order cancellation (soft delete via status or hard delete)
/// - Synced: On creation, status updates, assignment
///
/// IMPROVEMENT OPPORTUNITIES:
/// - [HIGH] Add composite indexes on (userId, status) and (driverId, status)
/// - [MEDIUM] Add estimatedDeliveryTime field for ETA tracking
/// - [LOW] Add cancellationReason field to track why orders fail
/// - [MEDIUM] Add distance field (calculated on creation) for analytics
/// - [HIGH] Add index on createdAt for time-based queries
/// - [LOW] Consider adding customerNotes and driverNotes fields
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

/// WHAT: OrderItem table schema for storing package/item details
///
/// WHY: Stores detailed information about the package being delivered. Separated from
/// Order table for better normalization and to allow future extension to multiple items
/// per order if business requirements change.
///
/// TABLE SCHEMA:
/// ```sql
/// CREATE TABLE order_items (
///   orderId TEXT PRIMARY KEY,               -- FK to orders.id (1:1 relationship)
///   category TEXT NOT NULL,                 -- Item category (e.g., 'Electronics', 'Food')
///   description TEXT NOT NULL,              -- Item description
///   weight REAL NOT NULL,                   -- Weight in kilograms
///   size TEXT NOT NULL                      -- 'small'|'medium'|'large'|'xlarge'
/// );
/// ```
///
/// RELATIONSHIPS:
/// - 1:1 with orders (one item belongs to one order, orderId is both PK and FK)
///
/// INDEXES:
/// - PRIMARY KEY on orderId (also serves as foreign key)
///
/// SIZE CATEGORIES:
/// - small: Fits in hand (e.g., phone, documents)
/// - medium: Fits in backpack (e.g., laptop, small box)
/// - large: Requires both hands (e.g., large box, appliances)
/// - xlarge: Requires van/truck (e.g., furniture, multiple boxes)
///
/// USAGE:
/// ```dart
/// // Create order item (must be done with order creation in transaction)
/// final item = OrderItemTableCompanion.insert(
///   orderId: order.id,
///   category: 'Electronics',
///   description: 'Laptop - Dell XPS 15',
///   weight: 2.5,
///   size: 'medium',
/// );
///
/// // Always use transaction for order + item creation
/// await database.transaction(() async {
///   await database.into(orderTable).insert(order);
///   await database.into(orderItemTable).insert(item);
/// });
/// ```
///
/// DATA LIFECYCLE:
/// - Created: Together with order in transaction
/// - Updated: Rarely (items don't change after order placement)
/// - Deleted: Together with order in transaction (cascade delete)
///
/// IMPROVEMENT OPPORTUNITIES:
/// - [MEDIUM] Add fragile boolean flag for handling instructions
/// - [LOW] Add imageUrl field for item photos
/// - [HIGH] Consider refactoring to support multiple items per order (1:N relationship)
/// - [LOW] Add dimensions (length, width, height) for better delivery planning
/// - [MEDIUM] Add specialInstructions field for delivery notes
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
