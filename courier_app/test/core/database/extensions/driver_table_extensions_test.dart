import 'package:flutter_test/flutter_test.dart';
import 'package:delivery_app/core/database/app_database.dart';
import 'package:delivery_app/core/database/extensions/driver_table_extensions.dart';
import 'package:drift/drift.dart';

void main() {
  group('DriverTableDataExtensions', () {
    late DriverTableData driverData;

    setUp(() {
      driverData = DriverTableData(
        id: 'drv_123',
        userId: 'usr_456',
        firstName: 'Amaka',
        lastName: 'Nwosu',
        email: 'amaka@example.com',
        phone: '+2348012345678',
        licenseNumber: 'LAG-67890-XY',
        vehiclePlate: 'ABC-123-XY',
        vehicleType: 'motorcycle',
        vehicleMake: 'Honda',
        vehicleModel: 'CB500X',
        vehicleYear: 2023,
        vehicleColor: 'Red',
        status: 'approved',
        availability: 'available',
        currentLatitude: 6.5244,
        currentLongitude: 3.3792,
        lastLocationUpdate: DateTime.parse('2025-10-05T10:30:00Z'),
        rating: 4.8,
        totalRatings: 25,
        rejectionReason: null,
        suspensionReason: null,
        suspensionExpiresAt: null,
        statusUpdatedAt: DateTime.parse('2025-10-04T14:00:00Z'),
        lastSyncedAt: DateTime.parse('2025-10-05T10:00:00Z'),
      );
    });

    group('toJsonMap', () {
      test('should convert DriverTableData to JSON map with all fields', () {
        final json = driverData.toJsonMap();

        expect(json['id'], equals('drv_123'));
        expect(json['userId'], equals('usr_456'));
        expect(json['firstName'], equals('Amaka'));
        expect(json['lastName'], equals('Nwosu'));
        expect(json['email'], equals('amaka@example.com'));
        expect(json['phone'], equals('+2348012345678'));
        expect(json['licenseNumber'], equals('LAG-67890-XY'));
        expect(json['status'], equals('approved'));
        expect(json['availability'], equals('available'));
        expect(json['rating'], equals(4.8));
        expect(json['totalRatings'], equals(25));
      });

      test('should include nested vehicleInfo object', () {
        final json = driverData.toJsonMap();

        expect(json['vehicleInfo'], isA<Map<String, dynamic>>());
        expect(json['vehicleInfo']['plate'], equals('ABC-123-XY'));
        expect(json['vehicleInfo']['type'], equals('motorcycle'));
        expect(json['vehicleInfo']['make'], equals('Honda'));
        expect(json['vehicleInfo']['model'], equals('CB500X'));
        expect(json['vehicleInfo']['year'], equals(2023));
        expect(json['vehicleInfo']['color'], equals('Red'));
      });

      test('should include currentLocation when coordinates are present', () {
        final json = driverData.toJsonMap();

        expect(json['currentLocation'], isA<Map<String, dynamic>>());
        expect(json['currentLocation']['latitude'], equals(6.5244));
        expect(json['currentLocation']['longitude'], equals(3.3792));
      });

      test('should include lastLocationUpdate as ISO8601 string', () {
        final json = driverData.toJsonMap();

        expect(json['lastLocationUpdate'], equals('2025-10-05T10:30:00.000Z'));
      });

      test('should exclude currentLocation when coordinates are null', () {
        final driverDataNoLocation = driverData.copyWith(
          currentLatitude: const Value(null),
          currentLongitude: const Value(null),
        );

        final json = driverDataNoLocation.toJsonMap();

        expect(json.containsKey('currentLocation'), isFalse);
      });

      test('should exclude lastLocationUpdate when null', () {
        final driverDataNoUpdate = driverData.copyWith(
          lastLocationUpdate: const Value(null),
        );

        final json = driverDataNoUpdate.toJsonMap();

        expect(json.containsKey('lastLocationUpdate'), isFalse);
      });
    });

    group('toRegistrationJson', () {
      test('should convert to snake_case flat structure for registration', () {
        final json = driverData.toRegistrationJson();

        expect(json['first_name'], equals('Amaka'));
        expect(json['last_name'], equals('Nwosu'));
        expect(json['email'], equals('amaka@example.com'));
        expect(json['phone_number'], equals('+2348012345678'));
        expect(json['license_number'], equals('LAG-67890-XY'));
        expect(json['vehicle_type'], equals('motorcycle'));
        expect(json['vehicle_plate'], equals('ABC-123-XY'));
        expect(json['vehicle_make'], equals('Honda'));
        expect(json['vehicle_model'], equals('CB500X'));
        expect(json['vehicle_year'], equals(2023));
      });

      test('should exclude status and availability fields', () {
        final json = driverData.toRegistrationJson();

        expect(json.containsKey('status'), isFalse);
        expect(json.containsKey('availability'), isFalse);
        expect(json.containsKey('rating'), isFalse);
        expect(json.containsKey('total_ratings'), isFalse);
      });

      test('should exclude id and userId fields', () {
        final json = driverData.toRegistrationJson();

        expect(json.containsKey('id'), isFalse);
        expect(json.containsKey('user_id'), isFalse);
      });

      test('should exclude vehicle_color (not required by backend)', () {
        final json = driverData.toRegistrationJson();

        expect(json.containsKey('vehicle_color'), isFalse);
      });

      test('should have exactly 10 required registration fields', () {
        final json = driverData.toRegistrationJson();

        expect(json.keys.length, equals(10));
        expect(json.containsKey('first_name'), isTrue);
        expect(json.containsKey('last_name'), isTrue);
        expect(json.containsKey('email'), isTrue);
        expect(json.containsKey('phone_number'), isTrue);
        expect(json.containsKey('license_number'), isTrue);
        expect(json.containsKey('vehicle_type'), isTrue);
        expect(json.containsKey('vehicle_plate'), isTrue);
        expect(json.containsKey('vehicle_make'), isTrue);
        expect(json.containsKey('vehicle_model'), isTrue);
        expect(json.containsKey('vehicle_year'), isTrue);
      });
    });

    group('toUpdateJson', () {
      test('should convert to camelCase with nested vehicleInfo', () {
        final json = driverData.toUpdateJson();

        expect(json['firstName'], equals('Amaka'));
        expect(json['lastName'], equals('Nwosu'));
        expect(json['email'], equals('amaka@example.com'));
        expect(json['phone'], equals('+2348012345678'));
        expect(json['licenseNumber'], equals('LAG-67890-XY'));
      });

      test('should include complete vehicleInfo object with color', () {
        final json = driverData.toUpdateJson();

        expect(json['vehicleInfo'], isA<Map<String, dynamic>>());
        expect(json['vehicleInfo']['plate'], equals('ABC-123-XY'));
        expect(json['vehicleInfo']['type'], equals('motorcycle'));
        expect(json['vehicleInfo']['make'], equals('Honda'));
        expect(json['vehicleInfo']['model'], equals('CB500X'));
        expect(json['vehicleInfo']['year'], equals(2023));
        expect(json['vehicleInfo']['color'], equals('Red'));
      });

      test('should exclude status and system fields', () {
        final json = driverData.toUpdateJson();

        expect(json.containsKey('status'), isFalse);
        expect(json.containsKey('availability'), isFalse);
        expect(json.containsKey('rating'), isFalse);
        expect(json.containsKey('totalRatings'), isFalse);
        expect(json.containsKey('id'), isFalse);
        expect(json.containsKey('userId'), isFalse);
      });

      test('should have exactly 6 fields (5 profile + vehicleInfo)', () {
        final json = driverData.toUpdateJson();

        expect(json.keys.length, equals(6));
        expect(json.containsKey('firstName'), isTrue);
        expect(json.containsKey('lastName'), isTrue);
        expect(json.containsKey('email'), isTrue);
        expect(json.containsKey('phone'), isTrue);
        expect(json.containsKey('licenseNumber'), isTrue);
        expect(json.containsKey('vehicleInfo'), isTrue);
      });
    });

    group('Edge Cases', () {
      test('should handle special characters in names', () {
        final specialDriver = driverData.copyWith(
          firstName: "O'Brien",
          lastName: 'Ngozi-Okafor',
        );

        final json = specialDriver.toJsonMap();
        expect(json['firstName'], equals("O'Brien"));
        expect(json['lastName'], equals('Ngozi-Okafor'));
      });

      test('should handle zero rating and ratings', () {
        final newDriver = driverData.copyWith(
          rating: 0.0,
          totalRatings: 0,
        );

        final json = newDriver.toJsonMap();
        expect(json['rating'], equals(0.0));
        expect(json['totalRatings'], equals(0));
      });

      test('should handle boundary coordinates (Nigeria)', () {
        final boundaryDriver = driverData.copyWith(
          currentLatitude: const Value(4.2406), // Southern Nigeria
          currentLongitude: const Value(14.6411), // Eastern Nigeria
        );

        final json = boundaryDriver.toJsonMap();
        expect(json['currentLocation']['latitude'], equals(4.2406));
        expect(json['currentLocation']['longitude'], equals(14.6411));
      });

      test('should handle future date in statusUpdatedAt', () {
        final futureDate = DateTime.now().add(const Duration(days: 30));
        final futureDriver = driverData.copyWith(
          statusUpdatedAt: Value(futureDate),
        );

        final json = futureDriver.toJsonMap();
        // Should not throw error, just serialize the date
        expect(json.containsKey('statusUpdatedAt'), isFalse); // Not in toJsonMap
      });

      test('should handle old vehicle year', () {
        final oldDriver = driverData.copyWith(
          vehicleYear: 1995,
        );

        final json = oldDriver.toRegistrationJson();
        expect(json['vehicle_year'], equals(1995));
      });
    });
  });
}
