part of '../app_database.dart';

/// Data Access Object for Order operations
///
/// Provides CRUD operations and queries for order and order item data
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
