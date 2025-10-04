import 'package:delivery_app/core/domain/value_objects/weight.dart';
import 'package:delivery_app/core/error/exceptions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Weight', () {
    group('constructor', () {
      test('should create Weight with valid kilograms', () {
        // Arrange & Act
        final weight = Weight(kilograms: 5.5);

        // Assert
        expect(weight.kilograms, 5.5);
        expect(weight.inGrams, 5500);
      });

      test('should create Weight with zero kilograms', () {
        // Arrange & Act
        final weight = Weight(kilograms: 0);

        // Assert
        expect(weight.kilograms, 0);
        expect(weight.inGrams, 0);
      });

      test('should create Weight with decimal precision', () {
        // Arrange & Act
        final weight = Weight(kilograms: 1.234);

        // Assert
        expect(weight.kilograms, 1.23); // Rounded to 2 decimals
        expect(weight.inGrams, 1230);
      });

      test('should throw ValidationException for negative kilograms', () {
        // Act & Assert
        expect(
          () => Weight(kilograms: -5),
          throwsA(isA<ValidationException>()),
        );
      });

      test('should throw ValidationException for NaN', () {
        // Act & Assert
        expect(
          () => Weight(kilograms: double.nan),
          throwsA(isA<ValidationException>()),
        );
      });

      test('should throw ValidationException for infinity', () {
        // Act & Assert
        expect(
          () => Weight(kilograms: double.infinity),
          throwsA(isA<ValidationException>()),
        );
      });
    });

    group('fromGrams', () {
      test('should create Weight from grams value', () {
        // Arrange & Act
        final weight = Weight.fromGrams(5000);

        // Assert
        expect(weight.kilograms, 5.0);
        expect(weight.inGrams, 5000);
      });

      test('should create Weight from zero grams', () {
        // Arrange & Act
        final weight = Weight.fromGrams(0);

        // Assert
        expect(weight.kilograms, 0);
        expect(weight.inGrams, 0);
      });

      test('should throw ValidationException for negative grams', () {
        // Act & Assert
        expect(
          () => Weight.fromGrams(-100),
          throwsA(isA<ValidationException>()),
        );
      });
    });

    group('formatting', () {
      test('should format weight in kilograms when >= 1 kg', () {
        // Arrange
        final weight = Weight(kilograms: 5.5);

        // Act
        final formatted = weight.formatted;

        // Assert
        expect(formatted, '5.50 kg');
      });

      test('should format weight in grams when < 1 kg', () {
        // Arrange
        final weight = Weight.fromGrams(750);

        // Act
        final formatted = weight.formatted;

        // Assert
        expect(formatted, '750 g');
      });

      test('should format zero weight in kilograms', () {
        // Arrange
        final weight = Weight(kilograms: 0);

        // Act
        final formatted = weight.formatted;

        // Assert
        expect(formatted, '0 g');
      });

      test('should format exactly 1 kg', () {
        // Arrange
        final weight = Weight(kilograms: 1);

        // Act
        final formatted = weight.formatted;

        // Assert
        expect(formatted, '1.00 kg');
      });

      test('should format large weights', () {
        // Arrange
        final weight = Weight(kilograms: 1234.56);

        // Act
        final formatted = weight.formatted;

        // Assert
        expect(formatted, '1234.56 kg');
      });

      test('should format small weights in grams', () {
        // Arrange
        final weight = Weight.fromGrams(250);

        // Act
        final formatted = weight.formatted;

        // Assert
        expect(formatted, '250 g');
      });
    });

    group('arithmetic operations', () {
      test('should add two Weight values', () {
        // Arrange
        final weight1 = Weight(kilograms: 5);
        final weight2 = Weight(kilograms: 3.5);

        // Act
        final result = weight1 + weight2;

        // Assert
        expect(result.kilograms, 8.5);
      });

      test('should subtract two Weight values', () {
        // Arrange
        final weight1 = Weight(kilograms: 10);
        final weight2 = Weight(kilograms: 3.5);

        // Act
        final result = weight1 - weight2;

        // Assert
        expect(result.kilograms, 6.5);
      });

      test('should throw ValidationException when subtraction results in negative', () {
        // Arrange
        final weight1 = Weight(kilograms: 5);
        final weight2 = Weight(kilograms: 10);

        // Act & Assert
        expect(
          () => weight1 - weight2,
          throwsA(isA<ValidationException>()),
        );
      });

      test('should multiply Weight by a factor', () {
        // Arrange
        final weight = Weight(kilograms: 5);

        // Act
        final result = weight * 2.5;

        // Assert
        expect(result.kilograms, 12.5);
      });

      test('should throw ValidationException when multiplying by negative', () {
        // Arrange
        final weight = Weight(kilograms: 5);

        // Act & Assert
        expect(
          () => weight * -2,
          throwsA(isA<ValidationException>()),
        );
      });
    });

    group('comparison', () {
      test('should return true when comparing equal weights', () {
        // Arrange
        final weight1 = Weight(kilograms: 5);
        final weight2 = Weight(kilograms: 5);

        // Act & Assert
        expect(weight1 == weight2, true);
        expect(weight1.hashCode, weight2.hashCode);
      });

      test('should return false when comparing different weights', () {
        // Arrange
        final weight1 = Weight(kilograms: 5);
        final weight2 = Weight(kilograms: 3);

        // Act & Assert
        expect(weight1 == weight2, false);
      });

      test('should support greater than comparison', () {
        // Arrange
        final weight1 = Weight(kilograms: 10);
        final weight2 = Weight(kilograms: 5);

        // Act & Assert
        expect(weight1 > weight2, true);
        expect(weight2 > weight1, false);
      });

      test('should support less than comparison', () {
        // Arrange
        final weight1 = Weight(kilograms: 5);
        final weight2 = Weight(kilograms: 10);

        // Act & Assert
        expect(weight1 < weight2, true);
        expect(weight2 < weight1, false);
      });

      test('should support greater than or equal comparison', () {
        // Arrange
        final weight1 = Weight(kilograms: 10);
        final weight2 = Weight(kilograms: 10);
        final weight3 = Weight(kilograms: 5);

        // Act & Assert
        expect(weight1 >= weight2, true);
        expect(weight1 >= weight3, true);
        expect(weight3 >= weight1, false);
      });

      test('should support less than or equal comparison', () {
        // Arrange
        final weight1 = Weight(kilograms: 5);
        final weight2 = Weight(kilograms: 5);
        final weight3 = Weight(kilograms: 10);

        // Act & Assert
        expect(weight1 <= weight2, true);
        expect(weight1 <= weight3, true);
        expect(weight3 <= weight1, false);
      });
    });

    group('isZero', () {
      test('should return true for zero weight', () {
        // Arrange
        final weight = Weight(kilograms: 0);

        // Act & Assert
        expect(weight.isZero, true);
      });

      test('should return false for non-zero weight', () {
        // Arrange
        final weight = Weight.fromGrams(10); // 10 grams = 0.01 kg (min precision)

        // Act & Assert
        expect(weight.isZero, false);
      });
    });

    group('copyWith', () {
      test('should create a copy with new kilograms', () {
        // Arrange
        final weight = Weight(kilograms: 5);

        // Act
        final copy = weight.copyWith(kilograms: 10);

        // Assert
        expect(copy.kilograms, 10);
        expect(weight.kilograms, 5); // Original unchanged
      });

      test('should create a copy with same kilograms if not specified', () {
        // Arrange
        final weight = Weight(kilograms: 5);

        // Act
        final copy = weight.copyWith();

        // Assert
        expect(copy.kilograms, 5);
        expect(copy == weight, true);
      });
    });

    group('props', () {
      test('should include kilograms in props', () {
        // Arrange
        final weight = Weight(kilograms: 5);

        // Act & Assert
        expect(weight.props, [5.0]);
      });
    });

    group('toString', () {
      test('should return formatted string', () {
        // Arrange
        final weight = Weight(kilograms: 5.5);

        // Act & Assert
        expect(weight.toString(), '5.50 kg');
      });
    });
  });
}
