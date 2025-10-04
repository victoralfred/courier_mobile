import 'package:equatable/equatable.dart';
import 'package:delivery_app/features/orders/domain/entities/order.dart';
import 'package:delivery_app/features/orders/domain/value_objects/order_status.dart';

abstract class OrderEvent extends Equatable {
  const OrderEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load orders for a user
class LoadUserOrders extends OrderEvent {
  final String userId;

  const LoadUserOrders(this.userId);

  @override
  List<Object?> get props => [userId];
}

/// Event to load active orders for a user
class LoadActiveOrders extends OrderEvent {
  final String userId;

  const LoadActiveOrders(this.userId);

  @override
  List<Object?> get props => [userId];
}

/// Event to load completed orders for a user
class LoadCompletedOrders extends OrderEvent {
  final String userId;

  const LoadCompletedOrders(this.userId);

  @override
  List<Object?> get props => [userId];
}

/// Event to load a single order by ID
class LoadOrderById extends OrderEvent {
  final String orderId;

  const LoadOrderById(this.orderId);

  @override
  List<Object?> get props => [orderId];
}

/// Event to create a new order
class CreateOrder extends OrderEvent {
  final Order order;

  const CreateOrder(this.order);

  @override
  List<Object?> get props => [order];
}

/// Event to update order status
class UpdateOrderStatus extends OrderEvent {
  final String orderId;
  final OrderStatus status;
  final DateTime? pickupStartedAt;
  final DateTime? pickupCompletedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  const UpdateOrderStatus({
    required this.orderId,
    required this.status,
    this.pickupStartedAt,
    this.pickupCompletedAt,
    this.completedAt,
    this.cancelledAt,
  });

  @override
  List<Object?> get props => [
        orderId,
        status,
        pickupStartedAt,
        pickupCompletedAt,
        completedAt,
        cancelledAt,
      ];
}

/// Event to assign driver to order
class AssignDriver extends OrderEvent {
  final String orderId;
  final String driverId;

  const AssignDriver({
    required this.orderId,
    required this.driverId,
  });

  @override
  List<Object?> get props => [orderId, driverId];
}

/// Event to cancel/delete order
class CancelOrder extends OrderEvent {
  final String orderId;

  const CancelOrder(this.orderId);

  @override
  List<Object?> get props => [orderId];
}

/// Event to watch order changes (for real-time updates)
class WatchOrder extends OrderEvent {
  final String orderId;

  const WatchOrder(this.orderId);

  @override
  List<Object?> get props => [orderId];
}

/// Event to watch active orders (for real-time updates)
class WatchActiveOrders extends OrderEvent {
  final String userId;

  const WatchActiveOrders(this.userId);

  @override
  List<Object?> get props => [userId];
}

/// Event when watched order updates
class WatchedOrderUpdated extends OrderEvent {
  final Order? order;

  const WatchedOrderUpdated(this.order);

  @override
  List<Object?> get props => [order];
}

/// Event when watched orders list updates
class OrdersListUpdated extends OrderEvent {
  final List<Order> orders;

  const OrdersListUpdated(this.orders);

  @override
  List<Object?> get props => [orders];
}
