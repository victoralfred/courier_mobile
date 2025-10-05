import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_app/core/database/app_database.dart';
import 'package:delivery_app/core/database/extensions/order_table_extensions.dart';
import 'package:drift/drift.dart';

void main() {
  group('OrderTableDataExtensions', () {
    late OrderTableData orderData;
    late OrderItemTableData itemData;

    setUp(() {
      orderData = OrderTableData(
        id: 'ord_123',
        userId: 'usr_456',
        driverId: 'drv_789',
        pickupAddress: '123 Ikoyi Road',
        pickupLatitude: 6.4521,
        pickupLongitude: 3.4198,
        pickupCity: 'Lagos',
        pickupState: 'Lagos',
        pickupPostcode: '101001',
        dropoffAddress: '456 Victoria Island',
        dropoffLatitude: 6.4281,
        dropoffLongitude: 3.4219,
        dropoffCity: 'Lagos',
        dropoffState: 'Lagos',
        dropoffPostcode: '101241',
        priceAmount: 2500.0,
        status: 'in_transit',
        pickupStartedAt: DateTime.parse('2025-10-05T10:00:00Z'),
        pickupCompletedAt: DateTime.parse('2025-10-05T10:15:00Z'),
        completedAt: null,
        cancelledAt: null,
        createdAt: DateTime.parse('2025-10-05T09:00:00Z'),
        updatedAt: DateTime.parse('2025-10-05T10:15:00Z'),
        lastSyncedAt: DateTime.parse('2025-10-05T10:15:00Z'),
      );

      itemData = OrderItemTableData(
        orderId: 'ord_123',
        category: 'Electronics',
        description: 'Dell XPS 15 Laptop',
        weight: 2.5,
        size: 'medium',
      );
    });

    group('toJsonMap', () {
      test('should convert OrderTableData to JSON map with all fields', () {
        final json = orderData.toJsonMap(item: itemData);

        expect(json['id'], equals('ord_123'));
        expect(json['userId'], equals('usr_456'));
        expect(json['driverId'], equals('drv_789'));
        expect(json['price'], equals(2500.0));
        expect(json['status'], equals('in_transit'));
      });

      test('should include nested pickupLocation object', () {
        final json = orderData.toJsonMap(item: itemData);

        expect(json['pickupLocation'], isA<Map<String, dynamic>>());
        expect(json['pickupLocation']['address'], equals('123 Ikoyi Road'));
        expect(json['pickupLocation']['latitude'], equals(6.4521));
        expect(json['pickupLocation']['longitude'], equals(3.4198));
        expect(json['pickupLocation']['city'], equals('Lagos'));
        expect(json['pickupLocation']['state'], equals('Lagos'));
        expect(json['pickupLocation']['postcode'], equals('101001'));
      });

      test('should include nested dropoffLocation object', () {
        final json = orderData.toJsonMap(item: itemData);

        expect(json['dropoffLocation'], isA<Map<String, dynamic>>());
        expect(json['dropoffLocation']['address'], equals('456 Victoria Island'));
        expect(json['dropoffLocation']['latitude'], equals(6.4281));
        expect(json['dropoffLocation']['longitude'], equals(3.4219));
        expect(json['dropoffLocation']['city'], equals('Lagos'));
        expect(json['dropoffLocation']['state'], equals('Lagos'));
        expect(json['dropoffLocation']['postcode'], equals('101241'));
      });

      test('should include nested item object when provided', () {
        final json = orderData.toJsonMap(item: itemData);

        expect(json['item'], isA<Map<String, dynamic>>());
        expect(json['item']['category'], equals('Electronics'));
        expect(json['item']['description'], equals('Dell XPS 15 Laptop'));
        expect(json['item']['weight'], equals(2.5));
        expect(json['item']['size'], equals('medium'));
      });

      test('should exclude item when not provided', () {
        final json = orderData.toJsonMap();

        expect(json.containsKey('item'), isFalse);
      });

      test('should include timestamp fields as ISO8601 strings', () {
        final json = orderData.toJsonMap(item: itemData);

        expect(json['pickupStartedAt'], equals('2025-10-05T10:00:00.000Z'));
        expect(json['pickupCompletedAt'], equals('2025-10-05T10:15:00.000Z'));
        expect(json['createdAt'], equals('2025-10-05T09:00:00.000Z'));
        expect(json['updatedAt'], equals('2025-10-05T10:15:00.000Z'));
      });

      test('should exclude null timestamp fields', () {
        final json = orderData.toJsonMap(item: itemData);

        expect(json.containsKey('completedAt'), isFalse);
        expect(json.containsKey('cancelledAt'), isFalse);
      });

      test('should exclude null driverId', () {
        final orderNoDriver = orderData.copyWith(driverId: const Value(null));
        final json = orderNoDriver.toJsonMap(item: itemData);

        expect(json.containsKey('driverId'), isFalse);
      });

      test('should exclude null pickup postcode', () {
        final orderNoPostcode = orderData.copyWith(pickupPostcode: const Value(null));
        final json = orderNoPostcode.toJsonMap(item: itemData);

        expect(json['pickupLocation'].containsKey('postcode'), isFalse);
      });

      test('should exclude null dropoff postcode', () {
        final orderNoPostcode = orderData.copyWith(dropoffPostcode: const Value(null));
        final json = orderNoPostcode.toJsonMap(item: itemData);

        expect(json['dropoffLocation'].containsKey('postcode'), isFalse);
      });
    });

    group('toCreateJson', () {
      test('should convert to creation format with required fields only', () {
        final json = orderData.toCreateJson(item: itemData);

        expect(json['pickupLocation'], isA<Map<String, dynamic>>());
        expect(json['dropoffLocation'], isA<Map<String, dynamic>>());
        expect(json['item'], isA<Map<String, dynamic>>());
        expect(json['price'], equals(2500.0));
      });

      test('should exclude server-generated fields (id, driverId)', () {
        final json = orderData.toCreateJson(item: itemData);

        expect(json.containsKey('id'), isFalse);
        expect(json.containsKey('userId'), isFalse);
        expect(json.containsKey('driverId'), isFalse);
      });

      test('should exclude timestamp fields', () {
        final json = orderData.toCreateJson(item: itemData);

        expect(json.containsKey('pickupStartedAt'), isFalse);
        expect(json.containsKey('pickupCompletedAt'), isFalse);
        expect(json.containsKey('completedAt'), isFalse);
        expect(json.containsKey('cancelledAt'), isFalse);
        expect(json.containsKey('createdAt'), isFalse);
        expect(json.containsKey('updatedAt'), isFalse);
      });

      test('should exclude status field', () {
        final json = orderData.toCreateJson(item: itemData);

        expect(json.containsKey('status'), isFalse);
      });

      test('should have exactly 4 top-level fields', () {
        final json = orderData.toCreateJson(item: itemData);

        expect(json.keys.length, equals(4));
        expect(json.containsKey('pickupLocation'), isTrue);
        expect(json.containsKey('dropoffLocation'), isTrue);
        expect(json.containsKey('item'), isTrue);
        expect(json.containsKey('price'), isTrue);
      });

      test('should include item data correctly', () {
        final json = orderData.toCreateJson(item: itemData);

        expect(json['item']['category'], equals('Electronics'));
        expect(json['item']['description'], equals('Dell XPS 15 Laptop'));
        expect(json['item']['weight'], equals(2.5));
        expect(json['item']['size'], equals('medium'));
      });

      test('should include nullable postcodes when present', () {
        final json = orderData.toCreateJson(item: itemData);

        expect(json['pickupLocation']['postcode'], equals('101001'));
        expect(json['dropoffLocation']['postcode'], equals('101241'));
      });

      test('should exclude nullable postcodes when null', () {
        final orderNoPostcode = orderData.copyWith(
          pickupPostcode: const Value(null),
          dropoffPostcode: const Value(null),
        );
        final json = orderNoPostcode.toCreateJson(item: itemData);

        expect(json['pickupLocation'].containsKey('postcode'), isFalse);
        expect(json['dropoffLocation'].containsKey('postcode'), isFalse);
      });
    });

    group('Edge Cases', () {
      test('should handle zero price', () {
        final freeOrder = orderData.copyWith(priceAmount: 0.0);
        final json = freeOrder.toJsonMap(item: itemData);

        expect(json['price'], equals(0.0));
      });

      test('should handle large prices', () {
        final expensiveOrder = orderData.copyWith(priceAmount: 99999.99);
        final json = expensiveOrder.toJsonMap(item: itemData);

        expect(json['price'], equals(99999.99));
      });

      test('should handle special characters in addresses', () {
        final specialOrder = orderData.copyWith(
          pickupAddress: "123 O'Connor St, Apt #5",
          dropoffAddress: '456 "The Plaza" Building',
        );
        final json = specialOrder.toJsonMap(item: itemData);

        expect(json['pickupLocation']['address'], equals("123 O'Connor St, Apt #5"));
        expect(json['dropoffLocation']['address'], equals('456 "The Plaza" Building'));
      });

      test('should handle all order statuses', () {
        final statuses = ['pending', 'assigned', 'pickup', 'in_transit', 'completed', 'cancelled'];

        for (final status in statuses) {
          final statusOrder = orderData.copyWith(status: status);
          final json = statusOrder.toJsonMap(item: itemData);
          expect(json['status'], equals(status));
        }
      });

      test('should handle completed order with all timestamps', () {
        final completedOrder = orderData.copyWith(
          status: 'completed',
          completedAt: Value(DateTime.parse('2025-10-05T11:00:00Z')),
        );
        final json = completedOrder.toJsonMap(item: itemData);

        expect(json['status'], equals('completed'));
        expect(json['completedAt'], equals('2025-10-05T11:00:00.000Z'));
      });

      test('should handle cancelled order', () {
        final cancelledOrder = orderData.copyWith(
          status: 'cancelled',
          cancelledAt: Value(DateTime.parse('2025-10-05T10:30:00Z')),
        );
        final json = cancelledOrder.toJsonMap(item: itemData);

        expect(json['status'], equals('cancelled'));
        expect(json['cancelledAt'], equals('2025-10-05T10:30:00.000Z'));
      });

      test('should handle order without pickup start or completion', () {
        final pendingOrder = orderData.copyWith(
          status: 'pending',
          pickupStartedAt: const Value(null),
          pickupCompletedAt: const Value(null),
        );
        final json = pendingOrder.toJsonMap(item: itemData);

        expect(json['status'], equals('pending'));
        expect(json.containsKey('pickupStartedAt'), isFalse);
        expect(json.containsKey('pickupCompletedAt'), isFalse);
      });

      test('should handle boundary coordinates (Nigeria)', () {
        final boundaryOrder = orderData.copyWith(
          pickupLatitude: 4.2406, // Southern Nigeria
          pickupLongitude: 14.6411, // Eastern Nigeria
          dropoffLatitude: 13.0059, // Northern Nigeria
          dropoffLongitude: 3.1059, // Western Nigeria
        );
        final json = boundaryOrder.toJsonMap(item: itemData);

        expect(json['pickupLocation']['latitude'], equals(4.2406));
        expect(json['pickupLocation']['longitude'], equals(14.6411));
        expect(json['dropoffLocation']['latitude'], equals(13.0059));
        expect(json['dropoffLocation']['longitude'], equals(3.1059));
      });
    });
  });

  group('OrderItemTableDataExtensions', () {
    late OrderItemTableData itemData;

    setUp(() {
      itemData = OrderItemTableData(
        orderId: 'ord_123',
        category: 'Electronics',
        description: 'Dell XPS 15 Laptop',
        weight: 2.5,
        size: 'medium',
      );
    });

    group('toJsonMap', () {
      test('should convert OrderItemTableData to JSON map', () {
        final json = itemData.toJsonMap();

        expect(json['category'], equals('Electronics'));
        expect(json['description'], equals('Dell XPS 15 Laptop'));
        expect(json['weight'], equals(2.5));
        expect(json['size'], equals('medium'));
      });

      test('should have exactly 4 fields (no orderId)', () {
        final json = itemData.toJsonMap();

        expect(json.keys.length, equals(4));
        expect(json.containsKey('orderId'), isFalse);
      });

      test('should handle all item sizes', () {
        final sizes = ['small', 'medium', 'large', 'xlarge'];

        for (final size in sizes) {
          final sizedItem = itemData.copyWith(size: size);
          final json = sizedItem.toJsonMap();
          expect(json['size'], equals(size));
        }
      });

      test('should handle various item categories', () {
        final categories = ['Electronics', 'Food', 'Documents', 'Clothing', 'Furniture'];

        for (final category in categories) {
          final categorizedItem = itemData.copyWith(category: category);
          final json = categorizedItem.toJsonMap();
          expect(json['category'], equals(category));
        }
      });

      test('should handle lightweight items', () {
        final lightItem = itemData.copyWith(weight: 0.1);
        final json = lightItem.toJsonMap();

        expect(json['weight'], equals(0.1));
      });

      test('should handle heavy items', () {
        final heavyItem = itemData.copyWith(weight: 50.0);
        final json = heavyItem.toJsonMap();

        expect(json['weight'], equals(50.0));
      });

      test('should handle long descriptions', () {
        final longDesc = 'A' * 500; // 500 characters
        final descItem = itemData.copyWith(description: longDesc);
        final json = descItem.toJsonMap();

        expect(json['description'].length, equals(500));
      });

      test('should handle special characters in description', () {
        final specialItem = itemData.copyWith(
          description: 'iPhone 15 Pro (256GB) - "Space Black" edition',
        );
        final json = specialItem.toJsonMap();

        expect(json['description'], equals('iPhone 15 Pro (256GB) - "Space Black" edition'));
      });
    });
  });
}
