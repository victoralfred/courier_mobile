import 'package:delivery_app/core/database/app_database.dart';
import 'package:delivery_app/core/domain/value_objects/coordinate.dart';
import 'package:delivery_app/core/domain/value_objects/location.dart';
import 'package:delivery_app/core/domain/value_objects/money.dart';
import 'package:delivery_app/features/orders/domain/entities/order.dart'
    as domain;
import 'package:delivery_app/features/orders/domain/entities/order_item.dart';
import 'package:delivery_app/features/orders/domain/value_objects/order_status.dart';
import 'package:delivery_app/features/orders/domain/value_objects/package_size.dart';

/// Mapper for converting between Order domain entity and database model
class OrderMapper {
  /// Converts database models to domain.Order entity
  static domain.Order fromDatabase(
    OrderTableData orderData,
    OrderItemTableData? itemData,
  ) {
    if (itemData == null) {
      throw ArgumentError('Order item data is required');
    }

    return domain.Order(
      id: orderData.id,
      userId: orderData.userId,
      driverId: orderData.driverId,
      pickupLocation: Location(
        address: orderData.pickupAddress,
        coordinate: Coordinate(
          latitude: orderData.pickupLatitude,
          longitude: orderData.pickupLongitude,
        ),
        city: orderData.pickupCity,
        state: orderData.pickupState,
        postcode: orderData.pickupPostcode,
      ),
      dropoffLocation: Location(
        address: orderData.dropoffAddress,
        coordinate: Coordinate(
          latitude: orderData.dropoffLatitude,
          longitude: orderData.dropoffLongitude,
        ),
        city: orderData.dropoffCity,
        state: orderData.dropoffState,
        postcode: orderData.dropoffPostcode,
      ),
      item: OrderItem(
        category: itemData.category,
        description: itemData.description,
        weight: itemData.weight,
        size: _parsePackageSize(itemData.size),
      ),
      price: Money(amount: orderData.priceAmount),
      status: _parseOrderStatus(orderData.status),
      pickupStartedAt: orderData.pickupStartedAt,
      pickupCompletedAt: orderData.pickupCompletedAt,
      completedAt: orderData.completedAt,
      cancelledAt: orderData.cancelledAt,
      createdAt: orderData.createdAt,
      updatedAt: orderData.updatedAt,
    );
  }

  /// Converts domain.Order entity to [OrderTableData]
  static OrderTableData toOrderTableData(domain.Order order) => OrderTableData(
        id: order.id,
        userId: order.userId,
        driverId: order.driverId,
        pickupAddress: order.pickupLocation.address,
        pickupLatitude: order.pickupLocation.coordinate.latitude,
        pickupLongitude: order.pickupLocation.coordinate.longitude,
        pickupCity: order.pickupLocation.city,
        pickupState: order.pickupLocation.state,
        pickupPostcode: order.pickupLocation.postcode,
        dropoffAddress: order.dropoffLocation.address,
        dropoffLatitude: order.dropoffLocation.coordinate.latitude,
        dropoffLongitude: order.dropoffLocation.coordinate.longitude,
        dropoffCity: order.dropoffLocation.city,
        dropoffState: order.dropoffLocation.state,
        dropoffPostcode: order.dropoffLocation.postcode,
        priceAmount: order.price.amount,
        status: order.status.name,
        pickupStartedAt: order.pickupStartedAt,
        pickupCompletedAt: order.pickupCompletedAt,
        completedAt: order.completedAt,
        cancelledAt: order.cancelledAt,
        createdAt: order.createdAt,
        updatedAt: order.updatedAt,
        lastSyncedAt: null,
      );

  /// Converts domain.Order entity to [OrderItemTableData]
  static OrderItemTableData toOrderItemTableData(domain.Order order) =>
      OrderItemTableData(
        orderId: order.id,
        category: order.item.category,
        description: order.item.description,
        weight: order.item.weight,
        size: order.item.size.toJson(),
      );

  /// Parses package size from string
  static PackageSize _parsePackageSize(String size) {
    switch (size.toLowerCase()) {
      case 'small':
        return PackageSize.small;
      case 'medium':
        return PackageSize.medium;
      case 'large':
        return PackageSize.large;
      case 'xlarge':
        return PackageSize.xlarge;
      default:
        return PackageSize.small; // Default fallback
    }
  }

  /// Parses order status from string
  static OrderStatus _parseOrderStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return OrderStatus.pending;
      case 'assigned':
        return OrderStatus.assigned;
      case 'pickup':
        return OrderStatus.pickup;
      case 'in_transit':
        return OrderStatus.inTransit;
      case 'completed':
        return OrderStatus.completed;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending; // Default fallback
    }
  }
}
