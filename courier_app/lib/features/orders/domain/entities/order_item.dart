import 'package:equatable/equatable.dart';
import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:delivery_app/core/error/exceptions.dart';
import 'package:delivery_app/features/orders/domain/value_objects/package_size.dart';

/// OrderItem entity representing a package/item for delivery
///
/// Immutable entity that ensures:
/// - Category and description are not empty
/// - Weight is positive (> 0)
/// - Package size is specified
///
/// Usage:
/// ```dart
/// final item = OrderItem(
///   category: 'Electronics',
///   description: 'iPhone 15 Pro',
///   weight: 0.2, // kilograms
///   size: PackageSize.small,
/// );
/// ```
class OrderItem extends Equatable {
  final String category;
  final String description;
  final double weight; // in kilograms
  final PackageSize size;

  const OrderItem._({
    required this.category,
    required this.description,
    required this.weight,
    required this.size,
  });

  /// Creates an OrderItem with validation
  ///
  /// Throws [ValidationException] if:
  /// - category is empty or whitespace
  /// - description is empty or whitespace
  /// - weight is <= 0
  factory OrderItem({
    required String category,
    required String description,
    required double weight,
    required PackageSize size,
  }) {
    // Trim whitespace
    final trimmedCategory = category.trim();
    final trimmedDescription = description.trim();

    // Validate category
    if (trimmedCategory.isEmpty) {
      throw const ValidationException(
        message: AppStrings.errorOrderItemEmptyCategory,
        fieldErrors: {'category': AppStrings.errorOrderItemEmptyCategory},
      );
    }

    // Validate description
    if (trimmedDescription.isEmpty) {
      throw const ValidationException(
        message: AppStrings.errorOrderItemEmptyDescription,
        fieldErrors: {'description': AppStrings.errorOrderItemEmptyDescription},
      );
    }

    // Validate weight
    if (weight <= 0) {
      throw const ValidationException(
        message: AppStrings.errorOrderItemInvalidWeight,
        fieldErrors: {'weight': AppStrings.errorOrderItemInvalidWeight},
      );
    }

    return OrderItem._(
      category: trimmedCategory,
      description: trimmedDescription,
      weight: weight,
      size: size,
    );
  }

  /// Get weight in kilograms
  double get weightInKg => weight;

  /// Create a copy with optional new values
  OrderItem copyWith({
    String? category,
    String? description,
    double? weight,
    PackageSize? size,
  }) =>
      OrderItem(
        category: category ?? this.category,
        description: description ?? this.description,
        weight: weight ?? this.weight,
        size: size ?? this.size,
      );

  @override
  List<Object?> get props => [category, description, weight, size];

  @override
  String toString() =>
      'OrderItem(category: $category, description: $description, '
      'weight: ${weight}kg, size: ${size.toJson()})';
}
