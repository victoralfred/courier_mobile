import 'package:delivery_app/core/domain/value_objects/coordinate.dart';
import 'package:delivery_app/core/domain/value_objects/location.dart';
import 'package:delivery_app/core/domain/value_objects/money.dart';
import 'package:delivery_app/features/orders/domain/entities/order.dart';
import 'package:delivery_app/features/orders/domain/entities/order_item.dart';
import 'package:delivery_app/features/orders/domain/value_objects/package_size.dart';
import 'package:delivery_app/features/orders/domain/value_objects/order_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Order', () {
    // Test data setup
    final pickupLocation = Location(
      address: '23 Marina Road',
      coordinate: Coordinate(latitude: 6.5244, longitude: 3.3792),
      city: 'Lagos',
      state: 'Lagos',
    );

    final dropoffLocation = Location(
      address: '10 Adeola Odeku',
      coordinate: Coordinate(latitude: 6.4281, longitude: 3.4219),
      city: 'Lagos',
      state: 'Lagos',
    );

    final orderItem = OrderItem(
      category: 'Electronics',
      description: 'iPhone 15 Pro',
      weight: 0.2,
      size: PackageSize.small,
    );

    final price = Money(amount: 2500);

    group('constructor', () {
      test('should create Order with all required fields', () {
        // Arrange & Act
        final order = Order(
          id: 'order-123',
          userId: 'user-456',
          pickupLocation: pickupLocation,
          dropoffLocation: dropoffLocation,
          item: orderItem,
          price: price,
          status: OrderStatus.pending,
          createdAt: DateTime(2025, 10, 2, 10, 0),
          updatedAt: DateTime(2025, 10, 2, 10, 0),
        );

        // Assert
        expect(order.id, 'order-123');
        expect(order.userId, 'user-456');
        expect(order.driverId, null);
        expect(order.pickupLocation, pickupLocation);
        expect(order.dropoffLocation, dropoffLocation);
        expect(order.item, orderItem);
        expect(order.price, price);
        expect(order.status, OrderStatus.pending);
        expect(order.pickupStartedAt, null);
        expect(order.pickupCompletedAt, null);
        expect(order.completedAt, null);
        expect(order.cancelledAt, null);
        expect(order.createdAt, DateTime(2025, 10, 2, 10, 0));
        expect(order.updatedAt, DateTime(2025, 10, 2, 10, 0));
      });

      test('should create Order with optional fields', () {
        // Arrange & Act
        final order = Order(
          id: 'order-123',
          userId: 'user-456',
          driverId: 'driver-789',
          pickupLocation: pickupLocation,
          dropoffLocation: dropoffLocation,
          item: orderItem,
          price: price,
          status: OrderStatus.inTransit,
          pickupStartedAt: DateTime(2025, 10, 2, 10, 30),
          pickupCompletedAt: DateTime(2025, 10, 2, 10, 45),
          createdAt: DateTime(2025, 10, 2, 10, 0),
          updatedAt: DateTime(2025, 10, 2, 10, 45),
        );

        // Assert
        expect(order.driverId, 'driver-789');
        expect(order.pickupStartedAt, DateTime(2025, 10, 2, 10, 30));
        expect(order.pickupCompletedAt, DateTime(2025, 10, 2, 10, 45));
      });
    });

    group('status checks', () {
      test('isPending should return true for pending status', () {
        // Arrange
        final order = Order(
          id: 'order-123',
          userId: 'user-456',
          pickupLocation: pickupLocation,
          dropoffLocation: dropoffLocation,
          item: orderItem,
          price: price,
          status: OrderStatus.pending,
          createdAt: DateTime(2025, 10, 2),
          updatedAt: DateTime(2025, 10, 2),
        );

        // Act & Assert
        expect(order.isPending, true);
        expect(order.isAssigned, false);
        expect(order.isInProgress, false);
        expect(order.isCompleted, false);
        expect(order.isCancelled, false);
      });

      test('isAssigned should return true for assigned status', () {
        // Arrange
        final order = Order(
          id: 'order-123',
          userId: 'user-456',
          driverId: 'driver-789',
          pickupLocation: pickupLocation,
          dropoffLocation: dropoffLocation,
          item: orderItem,
          price: price,
          status: OrderStatus.assigned,
          createdAt: DateTime(2025, 10, 2),
          updatedAt: DateTime(2025, 10, 2),
        );

        // Act & Assert
        expect(order.isAssigned, true);
        expect(order.isPending, false);
      });

      test('isInProgress should return true for pickup status', () {
        // Arrange
        final order = Order(
          id: 'order-123',
          userId: 'user-456',
          driverId: 'driver-789',
          pickupLocation: pickupLocation,
          dropoffLocation: dropoffLocation,
          item: orderItem,
          price: price,
          status: OrderStatus.pickup,
          createdAt: DateTime(2025, 10, 2),
          updatedAt: DateTime(2025, 10, 2),
        );

        // Act & Assert
        expect(order.isInProgress, true);
      });

      test('isInProgress should return true for inTransit status', () {
        // Arrange
        final order = Order(
          id: 'order-123',
          userId: 'user-456',
          driverId: 'driver-789',
          pickupLocation: pickupLocation,
          dropoffLocation: dropoffLocation,
          item: orderItem,
          price: price,
          status: OrderStatus.inTransit,
          createdAt: DateTime(2025, 10, 2),
          updatedAt: DateTime(2025, 10, 2),
        );

        // Act & Assert
        expect(order.isInProgress, true);
      });

      test('isCompleted should return true for completed status', () {
        // Arrange
        final order = Order(
          id: 'order-123',
          userId: 'user-456',
          driverId: 'driver-789',
          pickupLocation: pickupLocation,
          dropoffLocation: dropoffLocation,
          item: orderItem,
          price: price,
          status: OrderStatus.completed,
          completedAt: DateTime(2025, 10, 2, 11, 0),
          createdAt: DateTime(2025, 10, 2, 10, 0),
          updatedAt: DateTime(2025, 10, 2, 11, 0),
        );

        // Act & Assert
        expect(order.isCompleted, true);
        expect(order.isInProgress, false);
      });

      test('isCancelled should return true for cancelled status', () {
        // Arrange
        final order = Order(
          id: 'order-123',
          userId: 'user-456',
          pickupLocation: pickupLocation,
          dropoffLocation: dropoffLocation,
          item: orderItem,
          price: price,
          status: OrderStatus.cancelled,
          cancelledAt: DateTime(2025, 10, 2, 10, 30),
          createdAt: DateTime(2025, 10, 2, 10, 0),
          updatedAt: DateTime(2025, 10, 2, 10, 30),
        );

        // Act & Assert
        expect(order.isCancelled, true);
        expect(order.isCompleted, false);
      });
    });

    group('canBeAssignedToDriver', () {
      test('should return true for pending order', () {
        // Arrange
        final order = Order(
          id: 'order-123',
          userId: 'user-456',
          pickupLocation: pickupLocation,
          dropoffLocation: dropoffLocation,
          item: orderItem,
          price: price,
          status: OrderStatus.pending,
          createdAt: DateTime(2025, 10, 2),
          updatedAt: DateTime(2025, 10, 2),
        );

        // Act & Assert
        expect(order.canBeAssignedToDriver, true);
      });

      test('should return false for assigned order', () {
        // Arrange
        final order = Order(
          id: 'order-123',
          userId: 'user-456',
          driverId: 'driver-789',
          pickupLocation: pickupLocation,
          dropoffLocation: dropoffLocation,
          item: orderItem,
          price: price,
          status: OrderStatus.assigned,
          createdAt: DateTime(2025, 10, 2),
          updatedAt: DateTime(2025, 10, 2),
        );

        // Act & Assert
        expect(order.canBeAssignedToDriver, false);
      });
    });

    group('canBeCancelled', () {
      test('should return true for pending order', () {
        // Arrange
        final order = Order(
          id: 'order-123',
          userId: 'user-456',
          pickupLocation: pickupLocation,
          dropoffLocation: dropoffLocation,
          item: orderItem,
          price: price,
          status: OrderStatus.pending,
          createdAt: DateTime(2025, 10, 2),
          updatedAt: DateTime(2025, 10, 2),
        );

        // Act & Assert
        expect(order.canBeCancelled, true);
      });

      test('should return true for assigned order', () {
        // Arrange
        final order = Order(
          id: 'order-123',
          userId: 'user-456',
          driverId: 'driver-789',
          pickupLocation: pickupLocation,
          dropoffLocation: dropoffLocation,
          item: orderItem,
          price: price,
          status: OrderStatus.assigned,
          createdAt: DateTime(2025, 10, 2),
          updatedAt: DateTime(2025, 10, 2),
        );

        // Act & Assert
        expect(order.canBeCancelled, true);
      });

      test('should return false for completed order', () {
        // Arrange
        final order = Order(
          id: 'order-123',
          userId: 'user-456',
          driverId: 'driver-789',
          pickupLocation: pickupLocation,
          dropoffLocation: dropoffLocation,
          item: orderItem,
          price: price,
          status: OrderStatus.completed,
          completedAt: DateTime(2025, 10, 2, 11, 0),
          createdAt: DateTime(2025, 10, 2, 10, 0),
          updatedAt: DateTime(2025, 10, 2, 11, 0),
        );

        // Act & Assert
        expect(order.canBeCancelled, false);
      });
    });

    group('deliveryDistance', () {
      test('should calculate distance between pickup and dropoff', () {
        // Arrange
        final order = Order(
          id: 'order-123',
          userId: 'user-456',
          pickupLocation: pickupLocation,
          dropoffLocation: dropoffLocation,
          item: orderItem,
          price: price,
          status: OrderStatus.pending,
          createdAt: DateTime(2025, 10, 2),
          updatedAt: DateTime(2025, 10, 2),
        );

        // Act
        final distance = order.deliveryDistance;

        // Assert
        expect(distance.inKilometers, greaterThan(0));
        expect(distance.inKilometers, lessThan(20)); // Within Lagos
      });
    });

    group('copyWith', () {
      test('should create copy with updated status', () {
        // Arrange
        final order = Order(
          id: 'order-123',
          userId: 'user-456',
          pickupLocation: pickupLocation,
          dropoffLocation: dropoffLocation,
          item: orderItem,
          price: price,
          status: OrderStatus.pending,
          createdAt: DateTime(2025, 10, 2, 10, 0),
          updatedAt: DateTime(2025, 10, 2, 10, 0),
        );

        // Act
        final updated = order.copyWith(
          status: OrderStatus.assigned,
          driverId: 'driver-789',
          updatedAt: DateTime(2025, 10, 2, 10, 15),
        );

        // Assert
        expect(updated.status, OrderStatus.assigned);
        expect(updated.driverId, 'driver-789');
        expect(updated.updatedAt, DateTime(2025, 10, 2, 10, 15));
        expect(updated.id, order.id); // Unchanged
        expect(updated.userId, order.userId); // Unchanged
      });

      test('should create copy with pickup times', () {
        // Arrange
        final order = Order(
          id: 'order-123',
          userId: 'user-456',
          driverId: 'driver-789',
          pickupLocation: pickupLocation,
          dropoffLocation: dropoffLocation,
          item: orderItem,
          price: price,
          status: OrderStatus.assigned,
          createdAt: DateTime(2025, 10, 2, 10, 0),
          updatedAt: DateTime(2025, 10, 2, 10, 0),
        );

        // Act
        final updated = order.copyWith(
          status: OrderStatus.pickup,
          pickupStartedAt: DateTime(2025, 10, 2, 10, 30),
          updatedAt: DateTime(2025, 10, 2, 10, 30),
        );

        // Assert
        expect(updated.status, OrderStatus.pickup);
        expect(updated.pickupStartedAt, DateTime(2025, 10, 2, 10, 30));
      });
    });

    group('equality', () {
      test('should be equal when all fields are same', () {
        // Arrange
        final order1 = Order(
          id: 'order-123',
          userId: 'user-456',
          pickupLocation: pickupLocation,
          dropoffLocation: dropoffLocation,
          item: orderItem,
          price: price,
          status: OrderStatus.pending,
          createdAt: DateTime(2025, 10, 2),
          updatedAt: DateTime(2025, 10, 2),
        );

        final order2 = Order(
          id: 'order-123',
          userId: 'user-456',
          pickupLocation: pickupLocation,
          dropoffLocation: dropoffLocation,
          item: orderItem,
          price: price,
          status: OrderStatus.pending,
          createdAt: DateTime(2025, 10, 2),
          updatedAt: DateTime(2025, 10, 2),
        );

        // Act & Assert
        expect(order1, order2);
        expect(order1.hashCode, order2.hashCode);
      });

      test('should not be equal when id differs', () {
        // Arrange
        final order1 = Order(
          id: 'order-123',
          userId: 'user-456',
          pickupLocation: pickupLocation,
          dropoffLocation: dropoffLocation,
          item: orderItem,
          price: price,
          status: OrderStatus.pending,
          createdAt: DateTime(2025, 10, 2),
          updatedAt: DateTime(2025, 10, 2),
        );

        final order2 = Order(
          id: 'order-999',
          userId: 'user-456',
          pickupLocation: pickupLocation,
          dropoffLocation: dropoffLocation,
          item: orderItem,
          price: price,
          status: OrderStatus.pending,
          createdAt: DateTime(2025, 10, 2),
          updatedAt: DateTime(2025, 10, 2),
        );

        // Act & Assert
        expect(order1 == order2, false);
      });
    });
  });
}
