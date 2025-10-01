import 'package:equatable/equatable.dart';
import 'package:delivery_app/core/domain/value_objects/distance.dart';
import 'package:delivery_app/core/domain/value_objects/location.dart';
import 'package:delivery_app/core/domain/value_objects/money.dart';
import 'package:delivery_app/features/orders/domain/entities/order_item.dart';
import 'package:delivery_app/features/orders/domain/value_objects/order_status.dart';

/// Order entity for Nigerian courier delivery service
///
/// Represents a delivery order with pickup and dropoff locations,
/// item details, pricing, and status tracking through the delivery lifecycle.
///
/// Usage:
/// ```dart
/// final order = Order(
///   id: 'order-123',
///   userId: 'user-456',
///   pickupLocation: pickupLoc,
///   dropoffLocation: dropoffLoc,
///   item: orderItem,
///   price: Money(amount: 2500),
///   status: OrderStatus.pending,
///   createdAt: DateTime.now(),
///   updatedAt: DateTime.now(),
/// );
/// ```
class Order extends Equatable {
  final String id;
  final String userId;
  final String? driverId;
  final Location pickupLocation;
  final Location dropoffLocation;
  final OrderItem item;
  final Money price;
  final OrderStatus status;
  final DateTime? pickupStartedAt;
  final DateTime? pickupCompletedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Order({
    required this.id,
    required this.userId,
    this.driverId,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.item,
    required this.price,
    required this.status,
    this.pickupStartedAt,
    this.pickupCompletedAt,
    this.completedAt,
    this.cancelledAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Check if order is pending (waiting for driver assignment)
  bool get isPending => status == OrderStatus.pending;

  /// Check if order is assigned to a driver
  bool get isAssigned => status == OrderStatus.assigned;

  /// Check if order is in progress (pickup or in transit)
  bool get isInProgress =>
      status == OrderStatus.pickup || status == OrderStatus.inTransit;

  /// Check if order is completed
  bool get isCompleted => status == OrderStatus.completed;

  /// Check if order is cancelled
  bool get isCancelled => status == OrderStatus.cancelled;

  /// Check if order can be assigned to a driver
  bool get canBeAssignedToDriver => status == OrderStatus.pending;

  /// Check if order can be cancelled
  bool get canBeCancelled =>
      status == OrderStatus.pending || status == OrderStatus.assigned;

  /// Calculate delivery distance between pickup and dropoff locations
  Distance get deliveryDistance =>
      pickupLocation.distanceTo(dropoffLocation);

  /// Create a copy with optional new values
  Order copyWith({
    String? id,
    String? userId,
    String? driverId,
    Location? pickupLocation,
    Location? dropoffLocation,
    OrderItem? item,
    Money? price,
    OrderStatus? status,
    DateTime? pickupStartedAt,
    DateTime? pickupCompletedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Order(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        driverId: driverId ?? this.driverId,
        pickupLocation: pickupLocation ?? this.pickupLocation,
        dropoffLocation: dropoffLocation ?? this.dropoffLocation,
        item: item ?? this.item,
        price: price ?? this.price,
        status: status ?? this.status,
        pickupStartedAt: pickupStartedAt ?? this.pickupStartedAt,
        pickupCompletedAt: pickupCompletedAt ?? this.pickupCompletedAt,
        completedAt: completedAt ?? this.completedAt,
        cancelledAt: cancelledAt ?? this.cancelledAt,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  List<Object?> get props => [
        id,
        userId,
        driverId,
        pickupLocation,
        dropoffLocation,
        item,
        price,
        status,
        pickupStartedAt,
        pickupCompletedAt,
        completedAt,
        cancelledAt,
        createdAt,
        updatedAt,
      ];

  @override
  String toString() => 'Order(id: $id, status: ${status.displayName}, '
      'price: ${price.formatted})';
}
