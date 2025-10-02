import 'package:equatable/equatable.dart';
import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:delivery_app/core/error/exceptions.dart';

/// Weight value object representing metric weight (kilograms)
///
/// Immutable value object that ensures:
/// - Weight is always non-negative
/// - Weight is a valid number (not NaN or infinity)
/// - Precision to 2 decimal places (10 grams)
///
/// Usage:
/// ```dart
/// final packageWeight = Weight(kilograms: 5.5);
/// final totalWeight = packageWeight + Weight.fromGrams(500);
/// print(totalWeight.formatted); // 6.00 kg
/// ```
class Weight extends Equatable implements Comparable<Weight> {
  final double kilograms;

  const Weight._({required this.kilograms});

  /// Creates a Weight instance from kilograms
  ///
  /// Throws [ValidationException] if:
  /// - kilograms is negative
  /// - kilograms is NaN
  /// - kilograms is infinite
  factory Weight({required double kilograms}) {
    if (kilograms < 0) {
      throw const ValidationException(
        message: AppStrings.errorWeightNegative,
        fieldErrors: {'kilograms': AppStrings.errorWeightNegative},
      );
    }

    if (kilograms.isNaN) {
      throw const ValidationException(
        message: AppStrings.errorWeightInvalid,
        fieldErrors: {'kilograms': AppStrings.errorWeightInvalid},
      );
    }

    if (kilograms.isInfinite) {
      throw const ValidationException(
        message: AppStrings.errorWeightInvalid,
        fieldErrors: {'kilograms': AppStrings.errorWeightInvalid},
      );
    }

    // Round to 2 decimal places (10 grams precision)
    final roundedKilograms = (kilograms * 100).round() / 100;

    return Weight._(kilograms: roundedKilograms);
  }

  /// Creates a Weight instance from grams
  ///
  /// 1000 grams = 1 kilogram
  ///
  /// Throws [ValidationException] if grams is negative
  factory Weight.fromGrams(int grams) {
    if (grams < 0) {
      throw const ValidationException(
        message: AppStrings.errorWeightNegative,
        fieldErrors: {'grams': AppStrings.errorWeightNegative},
      );
    }

    return Weight(kilograms: grams / 1000);
  }

  /// Get weight in grams (smallest unit)
  int get inGrams => (kilograms * 1000).round();

  /// Check if weight is zero
  bool get isZero => kilograms == 0;

  /// Format weight with appropriate unit
  ///
  /// Returns kilograms for weights >= 1 kg, grams otherwise
  /// Examples:
  /// - 5.50 kg
  /// - 750 g
  String get formatted {
    if (kilograms >= 1) {
      return '${kilograms.toStringAsFixed(2)} kg';
    } else if (kilograms == 0) {
      return '0 g';
    } else {
      return '$inGrams g';
    }
  }

  /// Add two Weight values
  Weight operator +(Weight other) =>
      Weight(kilograms: kilograms + other.kilograms);

  /// Subtract two Weight values
  ///
  /// Throws [ValidationException] if result would be negative
  Weight operator -(Weight other) {
    final result = kilograms - other.kilograms;
    if (result < 0) {
      throw const ValidationException(
        message: AppStrings.errorWeightNegativeResult,
        fieldErrors: {'kilograms': AppStrings.errorWeightNegativeResult},
      );
    }
    return Weight(kilograms: result);
  }

  /// Multiply Weight by a factor
  ///
  /// Throws [ValidationException] if multiplier is negative
  Weight operator *(double multiplier) {
    if (multiplier < 0) {
      throw const ValidationException(
        message: AppStrings.errorWeightNegativeMultiplier,
        fieldErrors: {'multiplier': AppStrings.errorWeightNegativeMultiplier},
      );
    }
    return Weight(kilograms: kilograms * multiplier);
  }

  /// Greater than comparison
  bool operator >(Weight other) => kilograms > other.kilograms;

  /// Less than comparison
  bool operator <(Weight other) => kilograms < other.kilograms;

  /// Greater than or equal comparison
  bool operator >=(Weight other) => kilograms >= other.kilograms;

  /// Less than or equal comparison
  bool operator <=(Weight other) => kilograms <= other.kilograms;

  @override
  int compareTo(Weight other) => kilograms.compareTo(other.kilograms);

  /// Create a copy with optional new kilograms
  Weight copyWith({double? kilograms}) =>
      Weight(kilograms: kilograms ?? this.kilograms);

  @override
  List<Object?> get props => [kilograms];

  @override
  String toString() => formatted;
}
