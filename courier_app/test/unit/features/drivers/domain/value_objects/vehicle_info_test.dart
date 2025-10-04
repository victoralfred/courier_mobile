import 'package:delivery_app/core/error/exceptions.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/vehicle_info.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/vehicle_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VehicleInfo', () {
    group('constructor', () {
      test('should create VehicleInfo with all valid fields', () {
        // Arrange & Act
        final vehicleInfo = VehicleInfo(
          plate: 'ABC-123-XY',
          type: VehicleType.car,
          make: 'Toyota',
          model: 'Corolla',
          year: 2020,
          color: 'Silver',
        );

        // Assert
        expect(vehicleInfo.plate, 'ABC-123-XY');
        expect(vehicleInfo.type, VehicleType.car);
        expect(vehicleInfo.make, 'Toyota');
        expect(vehicleInfo.model, 'Corolla');
        expect(vehicleInfo.year, 2020);
        expect(vehicleInfo.color, 'Silver');
      });

      test('should create VehicleInfo for motorcycle', () {
        // Arrange & Act
        final vehicleInfo = VehicleInfo(
          plate: 'XYZ-456-AB',
          type: VehicleType.motorcycle,
          make: 'Honda',
          model: 'CG 125',
          year: 2019,
          color: 'Red',
        );

        // Assert
        expect(vehicleInfo.type, VehicleType.motorcycle);
        expect(vehicleInfo.make, 'Honda');
      });

      test('should throw ValidationException for empty plate', () {
        // Act & Assert
        expect(
          () => VehicleInfo(
            plate: '',
            type: VehicleType.car,
            make: 'Toyota',
            model: 'Corolla',
            year: 2020,
            color: 'Silver',
          ),
          throwsA(isA<ValidationException>()),
        );
      });

      test('should throw ValidationException for whitespace-only plate', () {
        // Act & Assert
        expect(
          () => VehicleInfo(
            plate: '   ',
            type: VehicleType.car,
            make: 'Toyota',
            model: 'Corolla',
            year: 2020,
            color: 'Silver',
          ),
          throwsA(isA<ValidationException>()),
        );
      });

      test('should throw ValidationException for empty make', () {
        // Act & Assert
        expect(
          () => VehicleInfo(
            plate: 'ABC-123-XY',
            type: VehicleType.car,
            make: '',
            model: 'Corolla',
            year: 2020,
            color: 'Silver',
          ),
          throwsA(isA<ValidationException>()),
        );
      });

      test('should throw ValidationException for empty model', () {
        // Act & Assert
        expect(
          () => VehicleInfo(
            plate: 'ABC-123-XY',
            type: VehicleType.car,
            make: 'Toyota',
            model: '',
            year: 2020,
            color: 'Silver',
          ),
          throwsA(isA<ValidationException>()),
        );
      });

      test('should throw ValidationException for empty color', () {
        // Act & Assert
        expect(
          () => VehicleInfo(
            plate: 'ABC-123-XY',
            type: VehicleType.car,
            make: 'Toyota',
            model: 'Corolla',
            year: 2020,
            color: '',
          ),
          throwsA(isA<ValidationException>()),
        );
      });

      test('should throw ValidationException for year before 1990', () {
        // Act & Assert
        expect(
          () => VehicleInfo(
            plate: 'ABC-123-XY',
            type: VehicleType.car,
            make: 'Toyota',
            model: 'Corolla',
            year: 1989,
            color: 'Silver',
          ),
          throwsA(isA<ValidationException>()),
        );
      });

      test('should throw ValidationException for future year', () {
        // Arrange
        final futureYear = DateTime.now().year + 2;

        // Act & Assert
        expect(
          () => VehicleInfo(
            plate: 'ABC-123-XY',
            type: VehicleType.car,
            make: 'Toyota',
            model: 'Corolla',
            year: futureYear,
            color: 'Silver',
          ),
          throwsA(isA<ValidationException>()),
        );
      });

      test('should accept current year', () {
        // Arrange
        final currentYear = DateTime.now().year;

        // Act
        final vehicleInfo = VehicleInfo(
          plate: 'ABC-123-XY',
          type: VehicleType.car,
          make: 'Toyota',
          model: 'Corolla',
          year: currentYear,
          color: 'Silver',
        );

        // Assert
        expect(vehicleInfo.year, currentYear);
      });

      test('should accept next year (for new models)', () {
        // Arrange
        final nextYear = DateTime.now().year + 1;

        // Act
        final vehicleInfo = VehicleInfo(
          plate: 'ABC-123-XY',
          type: VehicleType.car,
          make: 'Toyota',
          model: 'Corolla',
          year: nextYear,
          color: 'Silver',
        );

        // Assert
        expect(vehicleInfo.year, nextYear);
      });

      test('should trim whitespace from all string fields', () {
        // Arrange & Act
        final vehicleInfo = VehicleInfo(
          plate: '  ABC-123-XY  ',
          type: VehicleType.car,
          make: '  Toyota  ',
          model: '  Corolla  ',
          year: 2020,
          color: '  Silver  ',
        );

        // Assert
        expect(vehicleInfo.plate, 'ABC-123-XY');
        expect(vehicleInfo.make, 'Toyota');
        expect(vehicleInfo.model, 'Corolla');
        expect(vehicleInfo.color, 'Silver');
      });
    });

    group('displayName', () {
      test('should return formatted display name', () {
        // Arrange
        final vehicleInfo = VehicleInfo(
          plate: 'ABC-123-XY',
          type: VehicleType.car,
          make: 'Toyota',
          model: 'Corolla',
          year: 2020,
          color: 'Silver',
        );

        // Act
        final name = vehicleInfo.displayName;

        // Assert
        expect(name, '2020 Toyota Corolla (Silver)');
      });

      test('should return display name for motorcycle', () {
        // Arrange
        final vehicleInfo = VehicleInfo(
          plate: 'XYZ-456-AB',
          type: VehicleType.motorcycle,
          make: 'Honda',
          model: 'CG 125',
          year: 2019,
          color: 'Red',
        );

        // Act
        final name = vehicleInfo.displayName;

        // Assert
        expect(name, '2019 Honda CG 125 (Red)');
      });
    });

    group('copyWith', () {
      test('should create copy with new plate', () {
        // Arrange
        final vehicleInfo = VehicleInfo(
          plate: 'ABC-123-XY',
          type: VehicleType.car,
          make: 'Toyota',
          model: 'Corolla',
          year: 2020,
          color: 'Silver',
        );

        // Act
        final updated = vehicleInfo.copyWith(plate: 'XYZ-789-CD');

        // Assert
        expect(updated.plate, 'XYZ-789-CD');
        expect(updated.make, 'Toyota'); // Unchanged
      });

      test('should create copy with new type', () {
        // Arrange
        final vehicleInfo = VehicleInfo(
          plate: 'ABC-123-XY',
          type: VehicleType.car,
          make: 'Toyota',
          model: 'Corolla',
          year: 2020,
          color: 'Silver',
        );

        // Act
        final updated = vehicleInfo.copyWith(type: VehicleType.van);

        // Assert
        expect(updated.type, VehicleType.van);
      });

      test('should create identical copy when no parameters specified', () {
        // Arrange
        final vehicleInfo = VehicleInfo(
          plate: 'ABC-123-XY',
          type: VehicleType.car,
          make: 'Toyota',
          model: 'Corolla',
          year: 2020,
          color: 'Silver',
        );

        // Act
        final copy = vehicleInfo.copyWith();

        // Assert
        expect(copy, vehicleInfo);
      });
    });

    group('equality', () {
      test('should be equal when all fields are same', () {
        // Arrange
        final vehicleInfo1 = VehicleInfo(
          plate: 'ABC-123-XY',
          type: VehicleType.car,
          make: 'Toyota',
          model: 'Corolla',
          year: 2020,
          color: 'Silver',
        );

        final vehicleInfo2 = VehicleInfo(
          plate: 'ABC-123-XY',
          type: VehicleType.car,
          make: 'Toyota',
          model: 'Corolla',
          year: 2020,
          color: 'Silver',
        );

        // Act & Assert
        expect(vehicleInfo1, vehicleInfo2);
        expect(vehicleInfo1.hashCode, vehicleInfo2.hashCode);
      });

      test('should not be equal when plate differs', () {
        // Arrange
        final vehicleInfo1 = VehicleInfo(
          plate: 'ABC-123-XY',
          type: VehicleType.car,
          make: 'Toyota',
          model: 'Corolla',
          year: 2020,
          color: 'Silver',
        );

        final vehicleInfo2 = VehicleInfo(
          plate: 'XYZ-789-CD',
          type: VehicleType.car,
          make: 'Toyota',
          model: 'Corolla',
          year: 2020,
          color: 'Silver',
        );

        // Act & Assert
        expect(vehicleInfo1 == vehicleInfo2, false);
      });
    });

    group('toString', () {
      test('should return formatted string', () {
        // Arrange
        final vehicleInfo = VehicleInfo(
          plate: 'ABC-123-XY',
          type: VehicleType.car,
          make: 'Toyota',
          model: 'Corolla',
          year: 2020,
          color: 'Silver',
        );

        // Act
        final string = vehicleInfo.toString();

        // Assert
        expect(string, contains('ABC-123-XY'));
        expect(string, contains('Toyota'));
        expect(string, contains('Corolla'));
      });
    });
  });
}
