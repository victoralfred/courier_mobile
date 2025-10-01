import 'package:equatable/equatable.dart';
import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:delivery_app/core/error/exceptions.dart';

/// Money value object representing Nigerian Naira (NGN) currency
///
/// Immutable value object that ensures:
/// - Amount is always non-negative
/// - Amount is a valid number (not NaN or infinity)
/// - Currency is always NGN (Nigerian Naira)
/// - Precision to 2 decimal places (kobo)
///
/// Usage:
/// ```dart
/// final price = Money(amount: 1000.50);
/// final total = price + Money(amount: 200);
/// print(total.formatted); // ₦1,200.50
/// ```
class Money extends Equatable implements Comparable<Money> {
  final double amount;
  static const String currency = 'NGN';
  static const String currencySymbol = '₦';

  const Money._({required this.amount});

  /// Creates a Money instance from Naira amount
  ///
  /// Throws [ValidationException] if:
  /// - amount is negative
  /// - amount is NaN
  /// - amount is infinite
  factory Money({required double amount}) {
    if (amount < 0) {
      throw const ValidationException(
        message: AppStrings.errorMoneyNegativeAmount,
        fieldErrors: {'amount': AppStrings.errorMoneyNegativeAmount},
      );
    }

    if (amount.isNaN) {
      throw const ValidationException(
        message: AppStrings.errorMoneyInvalidAmount,
        fieldErrors: {'amount': AppStrings.errorMoneyInvalidAmount},
      );
    }

    if (amount.isInfinite) {
      throw const ValidationException(
        message: AppStrings.errorMoneyInvalidAmount,
        fieldErrors: {'amount': AppStrings.errorMoneyInvalidAmount},
      );
    }

    // Round to 2 decimal places (kobo precision)
    final roundedAmount = (amount * 100).round() / 100;

    return Money._(amount: roundedAmount);
  }

  /// Creates a Money instance from kobo (smallest currency unit)
  ///
  /// 100 kobo = 1 Naira
  ///
  /// Throws [ValidationException] if kobo is negative
  factory Money.fromKobo(int kobo) {
    if (kobo < 0) {
      throw const ValidationException(
        message: AppStrings.errorMoneyNegativeAmount,
        fieldErrors: {'kobo': AppStrings.errorMoneyNegativeAmount},
      );
    }

    return Money(amount: kobo / 100);
  }

  /// Get amount in kobo (smallest unit)
  int get inKobo => (amount * 100).round();

  /// Check if amount is zero
  bool get isZero => amount == 0;

  /// Format money with currency symbol and thousand separators
  ///
  /// Example: ₦1,234.56
  String get formatted {
    final parts = amount.toStringAsFixed(2).split('.');
    final integerPart = parts[0];
    final decimalPart = parts[1];

    // Add thousand separators
    final buffer = StringBuffer();
    var count = 0;

    for (var i = integerPart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(integerPart[i]);
      count++;
    }

    final formattedInteger = buffer.toString().split('').reversed.join();

    return '$currencySymbol$formattedInteger.$decimalPart';
  }

  /// Add two Money values
  Money operator +(Money other) => Money(amount: amount + other.amount);

  /// Subtract two Money values
  ///
  /// Throws [ValidationException] if result would be negative
  Money operator -(Money other) {
    final result = amount - other.amount;
    if (result < 0) {
      throw const ValidationException(
        message: AppStrings.errorMoneyNegativeResult,
        fieldErrors: {'amount': AppStrings.errorMoneyNegativeResult},
      );
    }
    return Money(amount: result);
  }

  /// Multiply Money by a factor
  ///
  /// Throws [ValidationException] if multiplier is negative
  Money operator *(double multiplier) {
    if (multiplier < 0) {
      throw const ValidationException(
        message: AppStrings.errorMoneyNegativeMultiplier,
        fieldErrors: {'multiplier': AppStrings.errorMoneyNegativeMultiplier},
      );
    }
    return Money(amount: amount * multiplier);
  }

  /// Greater than comparison
  bool operator >(Money other) => amount > other.amount;

  /// Less than comparison
  bool operator <(Money other) => amount < other.amount;

  /// Greater than or equal comparison
  bool operator >=(Money other) => amount >= other.amount;

  /// Less than or equal comparison
  bool operator <=(Money other) => amount <= other.amount;

  @override
  int compareTo(Money other) => amount.compareTo(other.amount);

  /// Create a copy with optional new amount
  Money copyWith({double? amount}) => Money(amount: amount ?? this.amount);

  @override
  List<Object?> get props => [amount, currency];

  @override
  String toString() => formatted;
}
