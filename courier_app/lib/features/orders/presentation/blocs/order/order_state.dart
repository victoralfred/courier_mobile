import 'package:equatable/equatable.dart';
import 'package:delivery_app/features/orders/domain/entities/order.dart';

abstract class OrderState extends Equatable {
  const OrderState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class OrderInitial extends OrderState {}

/// Loading state
class OrderLoading extends OrderState {}

/// State when orders are loaded successfully
class OrdersLoaded extends OrderState {
  final List<Order> orders;

  const OrdersLoaded(this.orders);

  @override
  List<Object?> get props => [orders];
}

/// State when a single order is loaded
class OrderLoaded extends OrderState {
  final Order order;

  const OrderLoaded(this.order);

  @override
  List<Object?> get props => [order];
}

/// State when order is created successfully
class OrderCreated extends OrderState {
  final Order order;

  const OrderCreated(this.order);

  @override
  List<Object?> get props => [order];
}

/// State when order is updated successfully
class OrderUpdated extends OrderState {
  final Order order;

  const OrderUpdated(this.order);

  @override
  List<Object?> get props => [order];
}

/// State when order is cancelled successfully
class OrderCancelled extends OrderState {
  final String orderId;

  const OrderCancelled(this.orderId);

  @override
  List<Object?> get props => [orderId];
}

/// State when watching order for real-time updates
class OrderWatching extends OrderState {
  final Order? order;

  const OrderWatching(this.order);

  @override
  List<Object?> get props => [order];
}

/// State when watching orders list for real-time updates
class OrdersWatching extends OrderState {
  final List<Order> orders;

  const OrdersWatching(this.orders);

  @override
  List<Object?> get props => [orders];
}

/// Error state
class OrderError extends OrderState {
  final String message;

  const OrderError(this.message);

  @override
  List<Object?> get props => [message];
}
