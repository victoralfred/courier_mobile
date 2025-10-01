import 'package:delivery_app/core/domain/value_objects/money.dart';
import 'package:delivery_app/core/error/exceptions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money', () {
    group('constructor', () {
      test('should create Money with valid amount in Naira', () {
        // Arrange & Act
        final money = Money(amount: 1000.50);

        // Assert
        expect(money.amount, 1000.50);
        expect(Money.currency, 'NGN');
        expect(Money.currencySymbol, '₦');
      });

      test('should create Money with zero amount', () {
        // Arrange & Act
        final money = Money(amount: 0);

        // Assert
        expect(money.amount, 0);
        expect(Money.currency, 'NGN');
      });

      test('should create Money with decimal kobo', () {
        // Arrange & Act
        final money = Money(amount: 1234.56);

        // Assert
        expect(money.amount, 1234.56);
        expect(money.inKobo, 123456);
      });

      test('should throw ValidationException for negative amount', () {
        // Act & Assert
        expect(
          () => Money(amount: -100),
          throwsA(isA<ValidationException>()),
        );
      });

      test('should throw ValidationException for NaN', () {
        // Act & Assert
        expect(
          () => Money(amount: double.nan),
          throwsA(isA<ValidationException>()),
        );
      });

      test('should throw ValidationException for infinity', () {
        // Act & Assert
        expect(
          () => Money(amount: double.infinity),
          throwsA(isA<ValidationException>()),
        );
      });
    });

    group('fromKobo', () {
      test('should create Money from kobo value', () {
        // Arrange & Act
        final money = Money.fromKobo(100000);

        // Assert
        expect(money.amount, 1000.00);
        expect(money.inKobo, 100000);
      });

      test('should create Money from zero kobo', () {
        // Arrange & Act
        final money = Money.fromKobo(0);

        // Assert
        expect(money.amount, 0);
        expect(money.inKobo, 0);
      });

      test('should throw ValidationException for negative kobo', () {
        // Act & Assert
        expect(
          () => Money.fromKobo(-100),
          throwsA(isA<ValidationException>()),
        );
      });
    });

    group('formatting', () {
      test('should format amount with Naira symbol', () {
        // Arrange
        final money = Money(amount: 1234.56);

        // Act
        final formatted = money.formatted;

        // Assert
        expect(formatted, '₦1,234.56');
      });

      test('should format zero amount', () {
        // Arrange
        final money = Money(amount: 0);

        // Act
        final formatted = money.formatted;

        // Assert
        expect(formatted, '₦0.00');
      });

      test('should format large amounts with thousand separators', () {
        // Arrange
        final money = Money(amount: 1234567.89);

        // Act
        final formatted = money.formatted;

        // Assert
        expect(formatted, '₦1,234,567.89');
      });

      test('should format whole numbers with .00', () {
        // Arrange
        final money = Money(amount: 1000);

        // Act
        final formatted = money.formatted;

        // Assert
        expect(formatted, '₦1,000.00');
      });
    });

    group('arithmetic operations', () {
      test('should add two Money values', () {
        // Arrange
        final money1 = Money(amount: 1000);
        final money2 = Money(amount: 500.50);

        // Act
        final result = money1 + money2;

        // Assert
        expect(result.amount, 1500.50);
      });

      test('should subtract two Money values', () {
        // Arrange
        final money1 = Money(amount: 1000);
        final money2 = Money(amount: 300.25);

        // Act
        final result = money1 - money2;

        // Assert
        expect(result.amount, 699.75);
      });

      test('should throw ValidationException when subtraction results in negative', () {
        // Arrange
        final money1 = Money(amount: 100);
        final money2 = Money(amount: 200);

        // Act & Assert
        expect(
          () => money1 - money2,
          throwsA(isA<ValidationException>()),
        );
      });

      test('should multiply Money by a factor', () {
        // Arrange
        final money = Money(amount: 100);

        // Act
        final result = money * 2.5;

        // Assert
        expect(result.amount, 250);
      });

      test('should throw ValidationException when multiplying by negative', () {
        // Arrange
        final money = Money(amount: 100);

        // Act & Assert
        expect(
          () => money * -2,
          throwsA(isA<ValidationException>()),
        );
      });
    });

    group('comparison', () {
      test('should return true when comparing equal amounts', () {
        // Arrange
        final money1 = Money(amount: 1000);
        final money2 = Money(amount: 1000);

        // Act & Assert
        expect(money1 == money2, true);
        expect(money1.hashCode, money2.hashCode);
      });

      test('should return false when comparing different amounts', () {
        // Arrange
        final money1 = Money(amount: 1000);
        final money2 = Money(amount: 500);

        // Act & Assert
        expect(money1 == money2, false);
      });

      test('should support greater than comparison', () {
        // Arrange
        final money1 = Money(amount: 1000);
        final money2 = Money(amount: 500);

        // Act & Assert
        expect(money1 > money2, true);
        expect(money2 > money1, false);
      });

      test('should support less than comparison', () {
        // Arrange
        final money1 = Money(amount: 500);
        final money2 = Money(amount: 1000);

        // Act & Assert
        expect(money1 < money2, true);
        expect(money2 < money1, false);
      });

      test('should support greater than or equal comparison', () {
        // Arrange
        final money1 = Money(amount: 1000);
        final money2 = Money(amount: 1000);
        final money3 = Money(amount: 500);

        // Act & Assert
        expect(money1 >= money2, true);
        expect(money1 >= money3, true);
        expect(money3 >= money1, false);
      });

      test('should support less than or equal comparison', () {
        // Arrange
        final money1 = Money(amount: 500);
        final money2 = Money(amount: 500);
        final money3 = Money(amount: 1000);

        // Act & Assert
        expect(money1 <= money2, true);
        expect(money1 <= money3, true);
        expect(money3 <= money1, false);
      });
    });

    group('isZero', () {
      test('should return true for zero amount', () {
        // Arrange
        final money = Money(amount: 0);

        // Act & Assert
        expect(money.isZero, true);
      });

      test('should return false for non-zero amount', () {
        // Arrange
        final money = Money(amount: 0.01);

        // Act & Assert
        expect(money.isZero, false);
      });
    });

    group('copyWith', () {
      test('should create a copy with new amount', () {
        // Arrange
        final money = Money(amount: 1000);

        // Act
        final copy = money.copyWith(amount: 2000);

        // Assert
        expect(copy.amount, 2000);
        expect(money.amount, 1000); // Original unchanged
      });

      test('should create a copy with same amount if not specified', () {
        // Arrange
        final money = Money(amount: 1000);

        // Act
        final copy = money.copyWith();

        // Assert
        expect(copy.amount, 1000);
        expect(copy == money, true);
      });
    });

    group('props', () {
      test('should include amount and currency in props', () {
        // Arrange
        final money = Money(amount: 1000);

        // Act & Assert
        expect(money.props, [1000.0, Money.currency]);
      });
    });
  });
}
