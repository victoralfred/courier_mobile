import 'package:dartz/dartz.dart';
import 'package:delivery_app/core/database/app_database.dart';
import 'package:delivery_app/core/error/failures.dart';
import 'package:delivery_app/features/orders/data/mappers/order_mapper.dart';
import 'package:delivery_app/features/orders/domain/entities/order.dart'
    as domain;
import 'package:delivery_app/features/orders/domain/repositories/order_repository.dart';
import 'package:delivery_app/features/orders/domain/value_objects/order_status.dart';

/// Implementation of [OrderRepository] with offline-first pattern
///
/// This repository follows the offline-first approach:
/// 1. Always check local database first
/// 2. Return cached data immediately if available
/// 3. Queue write operations when offline
/// 4. Sync with backend when online
class OrderRepositoryImpl implements OrderRepository {
  final AppDatabase _database;

  OrderRepositoryImpl({required AppDatabase database}) : _database = database;

  @override
  Future<Either<Failure, domain.Order>> getOrderById(String id) async {
    try {
      // Try to get from local database first (offline-first)
      final orderWithItem = await _database.orderDao.getOrderById(id);

      if (orderWithItem == null) {
        return const Left(
            CacheFailure(message: 'Order not found in local database'));
      }

      final order = OrderMapper.fromDatabase(
        orderWithItem.order,
        orderWithItem.item,
      );

      return Right(order);
    } catch (e) {
      return Left(
          CacheFailure(message: 'Failed to get order: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<domain.Order>>> getOrdersByUserId(
      String userId) async {
    try {
      // Get from local database (offline-first)
      final ordersData = await _database.orderDao.getOrdersByUserId(userId);

      // Get items for each order
      final orders = <domain.Order>[];
      for (final orderData in ordersData) {
        final orderWithItem =
            await _database.orderDao.getOrderById(orderData.id);
        if (orderWithItem != null) {
          orders.add(OrderMapper.fromDatabase(
            orderWithItem.order,
            orderWithItem.item,
          ));
        }
      }

      return Right(orders);
    } catch (e) {
      return Left(
          CacheFailure(message: 'Failed to get orders: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<domain.Order>>> getOrdersByDriverId(
      String driverId) async {
    try {
      // Get from local database (offline-first)
      final ordersData = await _database.orderDao.getOrdersByDriverId(driverId);

      // Get items for each order
      final orders = <domain.Order>[];
      for (final orderData in ordersData) {
        final orderWithItem =
            await _database.orderDao.getOrderById(orderData.id);
        if (orderWithItem != null) {
          orders.add(OrderMapper.fromDatabase(
            orderWithItem.order,
            orderWithItem.item,
          ));
        }
      }

      return Right(orders);
    } catch (e) {
      return Left(CacheFailure(
          message: 'Failed to get driver orders: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<domain.Order>>> getPendingOrders() async {
    try {
      // Get from local database (offline-first)
      final ordersData = await _database.orderDao.getPendingOrders();

      // Get items for each order
      final orders = <domain.Order>[];
      for (final orderData in ordersData) {
        final orderWithItem =
            await _database.orderDao.getOrderById(orderData.id);
        if (orderWithItem != null) {
          orders.add(OrderMapper.fromDatabase(
            orderWithItem.order,
            orderWithItem.item,
          ));
        }
      }

      return Right(orders);
    } catch (e) {
      return Left(CacheFailure(
          message: 'Failed to get pending orders: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<domain.Order>>> getActiveOrders(
      String userId) async {
    try {
      // Get from local database (offline-first)
      final ordersData = await _database.orderDao.getActiveOrders(userId);

      // Get items for each order
      final orders = <domain.Order>[];
      for (final orderData in ordersData) {
        final orderWithItem =
            await _database.orderDao.getOrderById(orderData.id);
        if (orderWithItem != null) {
          orders.add(OrderMapper.fromDatabase(
            orderWithItem.order,
            orderWithItem.item,
          ));
        }
      }

      return Right(orders);
    } catch (e) {
      return Left(CacheFailure(
          message: 'Failed to get active orders: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<domain.Order>>> getCompletedOrders(
      String userId) async {
    try {
      // Get from local database (offline-first)
      final ordersData = await _database.orderDao.getCompletedOrders(userId);

      // Get items for each order
      final orders = <domain.Order>[];
      for (final orderData in ordersData) {
        final orderWithItem =
            await _database.orderDao.getOrderById(orderData.id);
        if (orderWithItem != null) {
          orders.add(OrderMapper.fromDatabase(
            orderWithItem.order,
            orderWithItem.item,
          ));
        }
      }

      return Right(orders);
    } catch (e) {
      return Left(CacheFailure(
          message: 'Failed to get completed orders: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, domain.Order>> createOrder(domain.Order order) async {
    try {
      // Convert domain entity to database models
      final orderData = OrderMapper.toOrderTableData(order);
      final itemData = OrderMapper.toOrderItemTableData(order);

      // Save to local database (transaction ensures both are saved together)
      await _database.orderDao.insertOrderWithItem(
        order: orderData,
        item: itemData,
      );

      // TODO: Queue for sync when network is available
      // await _queueSyncOperation(
      //   entityType: 'order',
      //   entityId: order.id,
      //   operation: 'create',
      //   payload: jsonEncode({'order': orderData.toJson(), 'item': itemData.toJson()}),
      // );

      return Right(order);
    } catch (e) {
      return Left(
          CacheFailure(message: 'Failed to create order: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, domain.Order>> updateOrder(domain.Order order) async {
    try {
      // Convert domain entity to database model
      final orderData = OrderMapper.toOrderTableData(order);

      // Update in local database
      await _database.orderDao.updateOrder(orderData);

      // TODO: Queue for sync when network is available

      return Right(order);
    } catch (e) {
      return Left(
          CacheFailure(message: 'Failed to update order: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, domain.Order>> updateOrderStatus({
    required String orderId,
    required OrderStatus status,
    DateTime? pickupStartedAt,
    DateTime? pickupCompletedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
  }) async {
    try {
      // Update in local database
      await _database.orderDao.updateOrderStatus(
        orderId: orderId,
        status: status.name,
        pickupStartedAt: pickupStartedAt,
        pickupCompletedAt: pickupCompletedAt,
        completedAt: completedAt,
        cancelledAt: cancelledAt,
      );

      // Get updated order
      final result = await getOrderById(orderId);

      // TODO: Queue for sync when network is available

      return result;
    } catch (e) {
      return Left(CacheFailure(
          message: 'Failed to update order status: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, domain.Order>> assignOrderToDriver({
    required String orderId,
    required String driverId,
  }) async {
    try {
      // Update in local database
      await _database.orderDao.assignOrderToDriver(
        orderId: orderId,
        driverId: driverId,
      );

      // Get updated order
      final result = await getOrderById(orderId);

      // TODO: Queue for sync when network is available

      return result;
    } catch (e) {
      return Left(CacheFailure(
          message: 'Failed to assign order to driver: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> deleteOrder(String orderId) async {
    try {
      // Delete from local database (transaction handles order + item)
      await _database.orderDao.deleteOrder(orderId);

      // TODO: Queue for sync when network is available
      // await _queueSyncOperation(
      //   entityType: 'order',
      //   entityId: orderId,
      //   operation: 'delete',
      //   payload: jsonEncode({'id': orderId}),
      // );

      return const Right(true);
    } catch (e) {
      return Left(
          CacheFailure(message: 'Failed to delete order: ${e.toString()}'));
    }
  }

  @override
  Stream<domain.Order?> watchOrderById(String id) =>
      _database.orderDao.watchOrderById(id).asyncMap((orderData) async {
        if (orderData == null) return null;

        // Get the order item
        final orderWithItem = await _database.orderDao.getOrderById(id);
        if (orderWithItem == null) return null;

        return OrderMapper.fromDatabase(
          orderWithItem.order,
          orderWithItem.item,
        );
      });

  @override
  Stream<List<domain.Order>> watchActiveOrders(String userId) =>
      _database.orderDao.watchActiveOrders(userId).asyncMap((ordersData) async {
        final orders = <domain.Order>[];

        for (final orderData in ordersData) {
          final orderWithItem =
              await _database.orderDao.getOrderById(orderData.id);
          if (orderWithItem != null) {
            orders.add(OrderMapper.fromDatabase(
              orderWithItem.order,
              orderWithItem.item,
            ));
          }
        }

        return orders;
      });
}
