import 'package:delivery_app/features/drivers/domain/value_objects/availability_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AvailabilityStatus', () {
    group('values', () {
      test('should have all availability status values', () {
        // Act & Assert
        expect(AvailabilityStatus.values.length, 3);
        expect(AvailabilityStatus.values, contains(AvailabilityStatus.offline));
        expect(AvailabilityStatus.values, contains(AvailabilityStatus.available));
        expect(AvailabilityStatus.values, contains(AvailabilityStatus.busy));
      });
    });

    group('fromString', () {
      test('should parse offline from string', () {
        // Act
        final status = AvailabilityStatusHelper.fromString('offline');

        // Assert
        expect(status, AvailabilityStatus.offline);
      });

      test('should parse available from string', () {
        // Act
        final status = AvailabilityStatusHelper.fromString('available');

        // Assert
        expect(status, AvailabilityStatus.available);
      });

      test('should parse busy from string', () {
        // Act
        final status = AvailabilityStatusHelper.fromString('busy');

        // Assert
        expect(status, AvailabilityStatus.busy);
      });

      test('should throw ArgumentError for invalid string', () {
        // Act & Assert
        expect(
          () => AvailabilityStatusHelper.fromString('invalid'),
          throwsArgumentError,
        );
      });
    });

    group('toJson', () {
      test('should convert offline to string', () {
        // Act
        final json = AvailabilityStatus.offline.toJson();

        // Assert
        expect(json, 'offline');
      });

      test('should convert available to string', () {
        // Act
        final json = AvailabilityStatus.available.toJson();

        // Assert
        expect(json, 'available');
      });

      test('should convert busy to string', () {
        // Act
        final json = AvailabilityStatus.busy.toJson();

        // Assert
        expect(json, 'busy');
      });
    });

    group('displayName', () {
      test('should return display name for offline', () {
        // Act
        final name = AvailabilityStatus.offline.displayName;

        // Assert
        expect(name, 'Offline');
      });

      test('should return display name for available', () {
        // Act
        final name = AvailabilityStatus.available.displayName;

        // Assert
        expect(name, 'Available');
      });

      test('should return display name for busy', () {
        // Act
        final name = AvailabilityStatus.busy.displayName;

        // Assert
        expect(name, 'Busy');
      });
    });

    group('isOnline', () {
      test('should return true for available status', () {
        // Act & Assert
        expect(AvailabilityStatus.available.isOnline, true);
      });

      test('should return true for busy status', () {
        // Act & Assert
        expect(AvailabilityStatus.busy.isOnline, true);
      });

      test('should return false for offline status', () {
        // Act & Assert
        expect(AvailabilityStatus.offline.isOnline, false);
      });
    });

    group('canAcceptOrders', () {
      test('should return true for available status', () {
        // Act & Assert
        expect(AvailabilityStatus.available.canAcceptOrders, true);
      });

      test('should return false for busy status', () {
        // Act & Assert
        expect(AvailabilityStatus.busy.canAcceptOrders, false);
      });

      test('should return false for offline status', () {
        // Act & Assert
        expect(AvailabilityStatus.offline.canAcceptOrders, false);
      });
    });

    group('roundtrip conversion', () {
      test('should maintain value through fromString and toJson', () {
        // Arrange
        final statuses = AvailabilityStatus.values;

        for (final status in statuses) {
          // Act
          final json = status.toJson();
          final parsed = AvailabilityStatusHelper.fromString(json);

          // Assert
          expect(parsed, status);
        }
      });
    });
  });
}
