import 'package:delivery_app/features/orders/domain/value_objects/order_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OrderStatus', () {
    group('values', () {
      test('should have all order status values', () {
        // Act & Assert
        expect(OrderStatus.values.length, 6);
        expect(OrderStatus.values, contains(OrderStatus.pending));
        expect(OrderStatus.values, contains(OrderStatus.assigned));
        expect(OrderStatus.values, contains(OrderStatus.pickup));
        expect(OrderStatus.values, contains(OrderStatus.inTransit));
        expect(OrderStatus.values, contains(OrderStatus.completed));
        expect(OrderStatus.values, contains(OrderStatus.cancelled));
      });
    });

    group('fromString', () {
      test('should parse pending from string', () {
        // Act
        final status = OrderStatusHelper.fromString('pending');

        // Assert
        expect(status, OrderStatus.pending);
      });

      test('should parse assigned from string', () {
        // Act
        final status = OrderStatusHelper.fromString('assigned');

        // Assert
        expect(status, OrderStatus.assigned);
      });

      test('should parse pickup from string', () {
        // Act
        final status = OrderStatusHelper.fromString('pickup');

        // Assert
        expect(status, OrderStatus.pickup);
      });

      test('should parse picked_up as pickup from string', () {
        // Act - Backend API uses picked_up
        final status = OrderStatusHelper.fromString('picked_up');

        // Assert
        expect(status, OrderStatus.pickup);
      });

      test('should parse in_transit from string', () {
        // Act
        final status = OrderStatusHelper.fromString('in_transit');

        // Assert
        expect(status, OrderStatus.inTransit);
      });

      test('should parse completed from string', () {
        // Act
        final status = OrderStatusHelper.fromString('completed');

        // Assert
        expect(status, OrderStatus.completed);
      });

      test('should parse delivered as completed from string', () {
        // Act - Backend API uses delivered
        final status = OrderStatusHelper.fromString('delivered');

        // Assert
        expect(status, OrderStatus.completed);
      });

      test('should parse cancelled from string', () {
        // Act
        final status = OrderStatusHelper.fromString('cancelled');

        // Assert
        expect(status, OrderStatus.cancelled);
      });

      test('should throw ArgumentError for invalid string', () {
        // Act & Assert
        expect(
          () => OrderStatusHelper.fromString('invalid'),
          throwsArgumentError,
        );
      });
    });

    group('toJson', () {
      test('should convert pending to string', () {
        // Act
        final json = OrderStatus.pending.toJson();

        // Assert
        expect(json, 'pending');
      });

      test('should convert assigned to string', () {
        // Act
        final json = OrderStatus.assigned.toJson();

        // Assert
        expect(json, 'assigned');
      });

      test('should convert pickup to string', () {
        // Act
        final json = OrderStatus.pickup.toJson();

        // Assert
        expect(json, 'pickup');
      });

      test('should convert inTransit to string', () {
        // Act
        final json = OrderStatus.inTransit.toJson();

        // Assert
        expect(json, 'in_transit');
      });

      test('should convert completed to string', () {
        // Act
        final json = OrderStatus.completed.toJson();

        // Assert
        expect(json, 'completed');
      });

      test('should convert cancelled to string', () {
        // Act
        final json = OrderStatus.cancelled.toJson();

        // Assert
        expect(json, 'cancelled');
      });
    });

    group('displayName', () {
      test('should return display name for pending', () {
        // Act
        final name = OrderStatus.pending.displayName;

        // Assert
        expect(name, 'Pending');
      });

      test('should return display name for assigned', () {
        // Act
        final name = OrderStatus.assigned.displayName;

        // Assert
        expect(name, 'Assigned');
      });

      test('should return display name for pickup', () {
        // Act
        final name = OrderStatus.pickup.displayName;

        // Assert
        expect(name, 'Picking Up');
      });

      test('should return display name for inTransit', () {
        // Act
        final name = OrderStatus.inTransit.displayName;

        // Assert
        expect(name, 'In Transit');
      });

      test('should return display name for completed', () {
        // Act
        final name = OrderStatus.completed.displayName;

        // Assert
        expect(name, 'Completed');
      });

      test('should return display name for cancelled', () {
        // Act
        final name = OrderStatus.cancelled.displayName;

        // Assert
        expect(name, 'Cancelled');
      });
    });

    group('roundtrip conversion', () {
      test('should maintain value through fromString and toJson', () {
        // Arrange
        final statuses = OrderStatus.values;

        for (final status in statuses) {
          // Act
          final json = status.toJson();
          final parsed = OrderStatusHelper.fromString(json);

          // Assert
          expect(parsed, status);
        }
      });
    });
  });
}
