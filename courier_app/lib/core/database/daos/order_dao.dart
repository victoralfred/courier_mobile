part of '../app_database.dart';

/// WHAT: Data Access Object (DAO) for Order and OrderItem table operations
///
/// WHY: Encapsulates all database operations for delivery orders, providing a clean API for
/// order creation, status tracking, driver assignment, and order filtering. Manages the
/// relationship between orders and order items through transactions.
///
/// RESPONSIBILITIES:
/// - Order CRUD operations with transactional item handling
/// - Order status lifecycle management (pending -> completed/cancelled)
/// - Driver assignment and order filtering
/// - Order filtering by user, driver, status
/// - Real-time order streaming via watch methods
/// - Order-item relationship management through transactions
///
/// QUERY PATTERNS:
/// - getOrderById(): Returns order with joined item data (1:1 relationship)
/// - getOrdersByUserId(): Customer's order history (ordered by creation date)
/// - getOrdersByDriverId(): Driver's assigned orders
/// - getPendingOrders(): Unassigned orders waiting for driver assignment
/// - getActiveOrders(): Orders in progress (assigned, pickup, in_transit)
/// - getCompletedOrders(): Delivered orders (ordered by completion date)
/// - insertOrderWithItem(): Atomic transaction for order + item creation
/// - deleteOrder(): Cascading delete for order and item
///
/// USAGE:
/// ```dart
/// // Create order with item (transaction ensures atomicity)
/// final order = OrderTableCompanion.insert(
///   id: uuid.v4(),
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
/// final item = OrderItemTableCompanion.insert(
///   orderId: order.id,
///   category: 'Electronics',
///   description: 'Laptop',
///   weight: 2.5,
///   size: 'medium',
/// );
/// await database.orderDao.insertOrderWithItem(order: order, item: item);
///
/// // Assign driver to order
/// await database.orderDao.assignOrderToDriver(
///   orderId: order.id,
///   driverId: driver.id,
/// );
///
/// // Update order status as driver progresses
/// await database.orderDao.updateOrderStatus(
///   orderId: order.id,
///   status: 'pickup',
///   pickupStartedAt: DateTime.now(),
/// );
///
/// await database.orderDao.updateOrderStatus(
///   orderId: order.id,
///   status: 'in_transit',
///   pickupCompletedAt: DateTime.now(),
/// );
///
/// await database.orderDao.updateOrderStatus(
///   orderId: order.id,
///   status: 'completed',
///   completedAt: DateTime.now(),
/// );
///
/// // Watch active orders for real-time updates
/// database.orderDao.watchActiveOrders(userId).listen((orders) {
///   // Update UI when order status changes
/// });
///
/// // Delete order and item (cascading delete)
/// await database.orderDao.deleteOrder(order.id);
/// ```
///
/// ORDER STATUS WORKFLOW:
/// ```
/// pending -> assigned -> pickup -> in_transit -> completed
///    |         |          |            |
///    v         v          v            v
/// cancelled cancelled cancelled   cancelled
/// ```
///
/// TRANSACTION GUARANTEES:
/// - insertOrderWithItem(): Both order and item inserted or neither (atomic)
/// - deleteOrder(): Both order and item deleted together (cascading)
/// - All status updates include updatedAt timestamp
///
/// IMPROVEMENT OPPORTUNITIES:
/// - [HIGH] Add pagination support for large order lists (limit/offset)
/// - [MEDIUM] Add getOrdersByDateRange() for analytics and reporting
/// - [LOW] Add getOrderStatistics() for customer/driver dashboards
/// - [HIGH] Optimize getActiveOrders() with composite index on (userId, status)
/// - [MEDIUM] Add cancelOrder() method with cancellation reason
/// - [LOW] Add searchOrders() for filtering by address, item description, etc.
/// - [MEDIUM] Cache joined order+item queries to reduce redundant joins
@DriftAccessor(tables: [OrderTable, OrderItemTable])
class OrderDao extends DatabaseAccessor<AppDatabase> with _$OrderDaoMixin {
  OrderDao(super.db);

  /// Get order by ID with item
  Future<OrderWithItem?> getOrderById(String id) async {
    final order = await (select(orderTable)..where((o) => o.id.equals(id)))
        .getSingleOrNull();

    if (order == null) return null;

    final item = await (select(orderItemTable)
          ..where((i) => i.orderId.equals(id)))
        .getSingleOrNull();

    return OrderWithItem(order: order, item: item);
  }

  /// Get all orders for a user
  Future<List<OrderTableData>> getOrdersByUserId(String userId) async =>
      (select(orderTable)
            ..where((o) => o.userId.equals(userId))
            ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]))
          .get();

  /// Get all orders for a driver
  Future<List<OrderTableData>> getOrdersByDriverId(String driverId) async =>
      (select(orderTable)
            ..where((o) => o.driverId.equals(driverId))
            ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]))
          .get();

  /// Get pending orders (not assigned to driver)
  Future<List<OrderTableData>> getPendingOrders() async => (select(orderTable)
        ..where((o) => o.status.equals('pending'))
        ..orderBy([(o) => OrderingTerm.asc(o.createdAt)]))
      .get();

  /// Get active orders (assigned, pickup, in_transit)
  Future<List<OrderTableData>> getActiveOrders(String userId) async =>
      (select(orderTable)
            ..where((o) => o.userId.equals(userId))
            ..where((o) =>
                o.status.equals('assigned') |
                o.status.equals('pickup') |
                o.status.equals('in_transit'))
            ..orderBy([(o) => OrderingTerm.desc(o.updatedAt)]))
          .get();

  /// Get completed orders
  Future<List<OrderTableData>> getCompletedOrders(String userId) async =>
      (select(orderTable)
            ..where((o) => o.userId.equals(userId))
            ..where((o) => o.status.equals('completed'))
            ..orderBy([(o) => OrderingTerm.desc(o.completedAt)]))
          .get();

  /// Insert order with item (transaction)
  Future<void> insertOrderWithItem({
    required OrderTableData order,
    required OrderItemTableData item,
  }) async {
    await transaction(() async {
      await into(orderTable).insert(order);
      await into(orderItemTable).insert(item);
    });
  }

  /// Update order
  Future<void> updateOrder(OrderTableData order) async {
    await update(orderTable).replace(order);
  }

  /// Update order status
  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
    DateTime? pickupStartedAt,
    DateTime? pickupCompletedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
  }) async {
    await (update(orderTable)..where((o) => o.id.equals(orderId))).write(
      OrderTableCompanion(
        status: Value(status),
        pickupStartedAt: Value(pickupStartedAt),
        pickupCompletedAt: Value(pickupCompletedAt),
        completedAt: Value(completedAt),
        cancelledAt: Value(cancelledAt),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Assign order to driver
  Future<void> assignOrderToDriver({
    required String orderId,
    required String driverId,
  }) async {
    await (update(orderTable)..where((o) => o.id.equals(orderId))).write(
      OrderTableCompanion(
        driverId: Value(driverId),
        status: const Value('assigned'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Delete order with item (transaction)
  Future<int> deleteOrder(String orderId) async => transaction(() async {
        await (delete(orderItemTable)..where((i) => i.orderId.equals(orderId)))
            .go();
        return (delete(orderTable)..where((o) => o.id.equals(orderId))).go();
      });

  /// Mark order as synced
  Future<void> markAsSynced(String orderId) async {
    await (update(orderTable)..where((o) => o.id.equals(orderId))).write(
      OrderTableCompanion(
        lastSyncedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Watch order by ID for realtime updates
  Stream<OrderTableData?> watchOrderById(String id) =>
      (select(orderTable)..where((o) => o.id.equals(id))).watchSingleOrNull();

  /// Watch active orders for a user
  Stream<List<OrderTableData>> watchActiveOrders(String userId) =>
      (select(orderTable)
            ..where((o) => o.userId.equals(userId))
            ..where((o) =>
                o.status.equals('assigned') |
                o.status.equals('pickup') |
                o.status.equals('in_transit'))
            ..orderBy([(o) => OrderingTerm.desc(o.updatedAt)]))
          .watch();
}

/// Helper class to return order with item
class OrderWithItem {
  final OrderTableData order;
  final OrderItemTableData? item;

  OrderWithItem({required this.order, this.item});
}
