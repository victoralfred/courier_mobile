import 'package:dartz/dartz.dart';
import 'package:delivery_app/core/error/failures.dart';
import 'package:delivery_app/features/orders/domain/entities/order.dart' as domain;
import 'package:delivery_app/features/orders/domain/value_objects/order_status.dart';

/// Order repository interface
/// Defines the contract for order-related data operations
abstract class OrderRepository {
  /// Gets an order by ID with its item
  /// Returns domain.Order on success or [Failure] on error
  Future<Either<Failure, domain.Order>> getOrderById(String id);

  /// Gets all orders for a user
  /// Returns list of domain.Order on success or [Failure] on error
  Future<Either<Failure, List<domain.Order>>> getOrdersByUserId(String userId);

  /// Gets all orders for a driver
  /// Returns list of domain.Order on success or [Failure] on error
  Future<Either<Failure, List<domain.Order>>> getOrdersByDriverId(String driverId);

  /// Gets all pending orders (not assigned to driver)
  /// Returns list of domain.Order on success or [Failure] on error
  Future<Either<Failure, List<domain.Order>>> getPendingOrders();

  /// Gets active orders (assigned, pickup, in_transit)
  /// Returns list of domain.Order on success or [Failure] on error
  Future<Either<Failure, List<domain.Order>>> getActiveOrders(String userId);

  /// Gets completed orders
  /// Returns list of domain.Order on success or [Failure] on error
  Future<Either<Failure, List<domain.Order>>> getCompletedOrders(String userId);

  /// Creates a new order with its item
  /// Returns domain.Order on success or [Failure] on error
  Future<Either<Failure, domain.Order>> createOrder(domain.Order order);

  /// Updates an existing order
  /// Returns domain.Order on success or [Failure] on error
  Future<Either<Failure, domain.Order>> updateOrder(domain.Order order);

  /// Updates order status with optional timestamps
  /// Returns domain.Order on success or [Failure] on error
  Future<Either<Failure, domain.Order>> updateOrderStatus({
    required String orderId,
    required OrderStatus status,
    DateTime? pickupStartedAt,
    DateTime? pickupCompletedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
  });

  /// Assigns order to a driver
  /// Returns domain.Order on success or [Failure] on error
  Future<Either<Failure, domain.Order>> assignOrderToDriver({
    required String orderId,
    required String driverId,
  });

  /// Deletes an order with its item
  /// Returns [bool] on success or [Failure] on error
  Future<Either<Failure, bool>> deleteOrder(String orderId);

  /// Watches an order by ID for real-time updates
  /// Returns a stream of domain.Order or null if not found
  Stream<domain.Order?> watchOrderById(String id);

  /// Watches active orders for a user for real-time updates
  /// Returns a stream of list of domain.Order
  Stream<List<domain.Order>> watchActiveOrders(String userId);
}
