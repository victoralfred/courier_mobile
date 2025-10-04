import 'package:delivery_app/core/error/exceptions.dart';
import 'package:delivery_app/features/orders/domain/entities/order_item.dart';
import 'package:delivery_app/features/orders/domain/value_objects/package_size.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OrderItem', () {
    group('constructor', () {
      test('should create OrderItem with valid fields', () {
        // Arrange & Act
        final item = OrderItem(
          category: 'Electronics',
          description: 'iPhone 15 Pro',
          weight: 0.2,
          size: PackageSize.small,
        );

        // Assert
        expect(item.category, 'Electronics');
        expect(item.description, 'iPhone 15 Pro');
        expect(item.weight, 0.2);
        expect(item.size, PackageSize.small);
      });

      test('should create OrderItem with different package sizes', () {
        // Arrange & Act
        final smallItem = OrderItem(
          category: 'Documents',
          description: 'Contract papers',
          weight: 0.1,
          size: PackageSize.small,
        );

        final mediumItem = OrderItem(
          category: 'Clothing',
          description: 'Shirts and pants',
          weight: 2.5,
          size: PackageSize.medium,
        );

        final largeItem = OrderItem(
          category: 'Furniture',
          description: 'Office chair',
          weight: 15.0,
          size: PackageSize.large,
        );

        final xlargeItem = OrderItem(
          category: 'Appliances',
          description: 'Refrigerator',
          weight: 50.0,
          size: PackageSize.xlarge,
        );

        // Assert
        expect(smallItem.size, PackageSize.small);
        expect(mediumItem.size, PackageSize.medium);
        expect(largeItem.size, PackageSize.large);
        expect(xlargeItem.size, PackageSize.xlarge);
      });

      test('should throw ValidationException for empty category', () {
        // Act & Assert
        expect(
          () => OrderItem(
            category: '',
            description: 'iPhone',
            weight: 0.2,
            size: PackageSize.small,
          ),
          throwsA(isA<ValidationException>()),
        );
      });

      test('should throw ValidationException for whitespace-only category', () {
        // Act & Assert
        expect(
          () => OrderItem(
            category: '   ',
            description: 'iPhone',
            weight: 0.2,
            size: PackageSize.small,
          ),
          throwsA(isA<ValidationException>()),
        );
      });

      test('should throw ValidationException for empty description', () {
        // Act & Assert
        expect(
          () => OrderItem(
            category: 'Electronics',
            description: '',
            weight: 0.2,
            size: PackageSize.small,
          ),
          throwsA(isA<ValidationException>()),
        );
      });

      test('should throw ValidationException for negative weight', () {
        // Act & Assert
        expect(
          () => OrderItem(
            category: 'Electronics',
            description: 'iPhone',
            weight: -0.5,
            size: PackageSize.small,
          ),
          throwsA(isA<ValidationException>()),
        );
      });

      test('should throw ValidationException for zero weight', () {
        // Act & Assert
        expect(
          () => OrderItem(
            category: 'Electronics',
            description: 'iPhone',
            weight: 0,
            size: PackageSize.small,
          ),
          throwsA(isA<ValidationException>()),
        );
      });

      test('should trim whitespace from category and description', () {
        // Arrange & Act
        final item = OrderItem(
          category: '  Electronics  ',
          description: '  iPhone 15 Pro  ',
          weight: 0.2,
          size: PackageSize.small,
        );

        // Assert
        expect(item.category, 'Electronics');
        expect(item.description, 'iPhone 15 Pro');
      });
    });

    group('weightInKg', () {
      test('should return weight in kilograms', () {
        // Arrange
        final item = OrderItem(
          category: 'Electronics',
          description: 'Laptop',
          weight: 2.5,
          size: PackageSize.medium,
        );

        // Act & Assert
        expect(item.weightInKg, 2.5);
      });
    });

    group('copyWith', () {
      test('should create copy with new category', () {
        // Arrange
        final item = OrderItem(
          category: 'Electronics',
          description: 'iPhone',
          weight: 0.2,
          size: PackageSize.small,
        );

        // Act
        final updated = item.copyWith(category: 'Mobile Devices');

        // Assert
        expect(updated.category, 'Mobile Devices');
        expect(updated.description, 'iPhone'); // Unchanged
        expect(updated.weight, 0.2); // Unchanged
      });

      test('should create copy with new description', () {
        // Arrange
        final item = OrderItem(
          category: 'Electronics',
          description: 'iPhone',
          weight: 0.2,
          size: PackageSize.small,
        );

        // Act
        final updated = item.copyWith(description: 'iPhone 15 Pro Max');

        // Assert
        expect(updated.description, 'iPhone 15 Pro Max');
        expect(updated.category, 'Electronics'); // Unchanged
      });

      test('should create copy with new weight', () {
        // Arrange
        final item = OrderItem(
          category: 'Electronics',
          description: 'iPhone',
          weight: 0.2,
          size: PackageSize.small,
        );

        // Act
        final updated = item.copyWith(weight: 0.25);

        // Assert
        expect(updated.weight, 0.25);
      });

      test('should create copy with new size', () {
        // Arrange
        final item = OrderItem(
          category: 'Electronics',
          description: 'iPhone',
          weight: 0.2,
          size: PackageSize.small,
        );

        // Act
        final updated = item.copyWith(size: PackageSize.medium);

        // Assert
        expect(updated.size, PackageSize.medium);
      });

      test('should create identical copy when no parameters specified', () {
        // Arrange
        final item = OrderItem(
          category: 'Electronics',
          description: 'iPhone',
          weight: 0.2,
          size: PackageSize.small,
        );

        // Act
        final copy = item.copyWith();

        // Assert
        expect(copy, item);
      });
    });

    group('equality', () {
      test('should be equal when all fields are same', () {
        // Arrange
        final item1 = OrderItem(
          category: 'Electronics',
          description: 'iPhone',
          weight: 0.2,
          size: PackageSize.small,
        );

        final item2 = OrderItem(
          category: 'Electronics',
          description: 'iPhone',
          weight: 0.2,
          size: PackageSize.small,
        );

        // Act & Assert
        expect(item1, item2);
        expect(item1.hashCode, item2.hashCode);
      });

      test('should not be equal when category differs', () {
        // Arrange
        final item1 = OrderItem(
          category: 'Electronics',
          description: 'iPhone',
          weight: 0.2,
          size: PackageSize.small,
        );

        final item2 = OrderItem(
          category: 'Mobile',
          description: 'iPhone',
          weight: 0.2,
          size: PackageSize.small,
        );

        // Act & Assert
        expect(item1 == item2, false);
      });
    });

    group('toString', () {
      test('should return formatted string', () {
        // Arrange
        final item = OrderItem(
          category: 'Electronics',
          description: 'iPhone 15 Pro',
          weight: 0.2,
          size: PackageSize.small,
        );

        // Act
        final string = item.toString();

        // Assert
        expect(string, contains('Electronics'));
        expect(string, contains('iPhone 15 Pro'));
        expect(string, contains('0.2'));
        expect(string, contains('small'));
      });
    });
  });
}
