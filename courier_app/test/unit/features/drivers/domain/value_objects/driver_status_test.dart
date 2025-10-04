import 'package:delivery_app/features/drivers/domain/value_objects/driver_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DriverStatus', () {
    group('values', () {
      test('should have all driver status values', () {
        // Act & Assert
        expect(DriverStatus.values.length, 4);
        expect(DriverStatus.values, contains(DriverStatus.pending));
        expect(DriverStatus.values, contains(DriverStatus.approved));
        expect(DriverStatus.values, contains(DriverStatus.rejected));
        expect(DriverStatus.values, contains(DriverStatus.suspended));
      });
    });

    group('fromString', () {
      test('should parse pending from string', () {
        // Act
        final status = DriverStatusHelper.fromString('pending');

        // Assert
        expect(status, DriverStatus.pending);
      });

      test('should parse approved from string', () {
        // Act
        final status = DriverStatusHelper.fromString('approved');

        // Assert
        expect(status, DriverStatus.approved);
      });

      test('should parse rejected from string', () {
        // Act
        final status = DriverStatusHelper.fromString('rejected');

        // Assert
        expect(status, DriverStatus.rejected);
      });

      test('should parse suspended from string', () {
        // Act
        final status = DriverStatusHelper.fromString('suspended');

        // Assert
        expect(status, DriverStatus.suspended);
      });

      test('should throw ArgumentError for invalid string', () {
        // Act & Assert
        expect(
          () => DriverStatusHelper.fromString('invalid'),
          throwsArgumentError,
        );
      });
    });

    group('toJson', () {
      test('should convert pending to string', () {
        // Act
        final json = DriverStatus.pending.toJson();

        // Assert
        expect(json, 'pending');
      });

      test('should convert approved to string', () {
        // Act
        final json = DriverStatus.approved.toJson();

        // Assert
        expect(json, 'approved');
      });

      test('should convert rejected to string', () {
        // Act
        final json = DriverStatus.rejected.toJson();

        // Assert
        expect(json, 'rejected');
      });

      test('should convert suspended to string', () {
        // Act
        final json = DriverStatus.suspended.toJson();

        // Assert
        expect(json, 'suspended');
      });
    });

    group('displayName', () {
      test('should return display name for pending', () {
        // Act
        final name = DriverStatus.pending.displayName;

        // Assert
        expect(name, 'Pending Verification');
      });

      test('should return display name for approved', () {
        // Act
        final name = DriverStatus.approved.displayName;

        // Assert
        expect(name, 'Approved');
      });

      test('should return display name for rejected', () {
        // Act
        final name = DriverStatus.rejected.displayName;

        // Assert
        expect(name, 'Rejected');
      });

      test('should return display name for suspended', () {
        // Act
        final name = DriverStatus.suspended.displayName;

        // Assert
        expect(name, 'Suspended');
      });
    });

    group('roundtrip conversion', () {
      test('should maintain value through fromString and toJson', () {
        // Arrange
        final statuses = DriverStatus.values;

        for (final status in statuses) {
          // Act
          final json = status.toJson();
          final parsed = DriverStatusHelper.fromString(json);

          // Assert
          expect(parsed, status);
        }
      });
    });
  });
}
