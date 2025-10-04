import 'package:delivery_app/features/drivers/domain/value_objects/vehicle_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VehicleType', () {
    group('values', () {
      test('should have all vehicle type values', () {
        // Act & Assert
        expect(VehicleType.values.length, 4);
        expect(VehicleType.values, contains(VehicleType.motorcycle));
        expect(VehicleType.values, contains(VehicleType.car));
        expect(VehicleType.values, contains(VehicleType.van));
        expect(VehicleType.values, contains(VehicleType.bicycle));
      });
    });

    group('fromString', () {
      test('should parse motorcycle from string', () {
        // Act
        final type = VehicleTypeHelper.fromString('motorcycle');

        // Assert
        expect(type, VehicleType.motorcycle);
      });

      test('should parse car from string', () {
        // Act
        final type = VehicleTypeHelper.fromString('car');

        // Assert
        expect(type, VehicleType.car);
      });

      test('should parse van from string', () {
        // Act
        final type = VehicleTypeHelper.fromString('van');

        // Assert
        expect(type, VehicleType.van);
      });

      test('should parse bicycle from string', () {
        // Act
        final type = VehicleTypeHelper.fromString('bicycle');

        // Assert
        expect(type, VehicleType.bicycle);
      });

      test('should throw ArgumentError for invalid string', () {
        // Act & Assert
        expect(
          () => VehicleTypeHelper.fromString('invalid'),
          throwsArgumentError,
        );
      });
    });

    group('toJson', () {
      test('should convert motorcycle to string', () {
        // Act
        final json = VehicleType.motorcycle.toJson();

        // Assert
        expect(json, 'motorcycle');
      });

      test('should convert car to string', () {
        // Act
        final json = VehicleType.car.toJson();

        // Assert
        expect(json, 'car');
      });

      test('should convert van to string', () {
        // Act
        final json = VehicleType.van.toJson();

        // Assert
        expect(json, 'van');
      });

      test('should convert bicycle to string', () {
        // Act
        final json = VehicleType.bicycle.toJson();

        // Assert
        expect(json, 'bicycle');
      });
    });

    group('displayName', () {
      test('should return display name for motorcycle', () {
        // Act
        final name = VehicleType.motorcycle.displayName;

        // Assert
        expect(name, 'Motorcycle');
      });

      test('should return display name for car', () {
        // Act
        final name = VehicleType.car.displayName;

        // Assert
        expect(name, 'Car');
      });

      test('should return display name for van', () {
        // Act
        final name = VehicleType.van.displayName;

        // Assert
        expect(name, 'Van');
      });

      test('should return display name for bicycle', () {
        // Act
        final name = VehicleType.bicycle.displayName;

        // Assert
        expect(name, 'Bicycle');
      });
    });

    group('roundtrip conversion', () {
      test('should maintain value through fromString and toJson', () {
        // Arrange
        final types = VehicleType.values;

        for (final type in types) {
          // Act
          final json = type.toJson();
          final parsed = VehicleTypeHelper.fromString(json);

          // Assert
          expect(parsed, type);
        }
      });
    });
  });
}
