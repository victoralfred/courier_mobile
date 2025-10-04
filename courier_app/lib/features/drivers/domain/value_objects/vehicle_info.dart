import 'package:equatable/equatable.dart';
import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:delivery_app/core/error/exceptions.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/vehicle_type.dart';

/// [VehicleInfo] - Immutable value object representing driver vehicle details
///
/// **What it does:**
/// - Represents complete vehicle information for driver
/// - Enforces vehicle data validation rules
/// - Ensures valid plate number, make, model, year, color
/// - Type-safe vehicle representation
/// - Immutable with copyWith pattern
/// - Uses VehicleType enum for type safety
///
/// **Why it exists:**
/// - Validates vehicle data for driver onboarding
/// - Prevents invalid vehicle information
/// - Enables vehicle-based features (type-specific pricing, capacity)
/// - Required for driver verification process
/// - Supports vehicle tracking and management
/// - Clean Architecture value object pattern
///
/// **Validation Rules:**
/// - **Plate Number**: Non-empty, trimmed
/// - **Make**: Non-empty, trimmed (e.g., Toyota, Honda, Bajaj)
/// - **Model**: Non-empty, trimmed (e.g., Corolla, CBR, Boxer)
/// - **Year**: 1990 to (current year + 1) for new models
/// - **Color**: Non-empty, trimmed
/// - **Type**: Valid VehicleType enum (motorcycle, car, van, bicycle)
///
/// **Business Context:**
/// - Nigerian courier service supports multiple vehicle types
/// - Plate numbers follow local format (e.g., ABC-123-XY)
/// - Vehicle age affects insurance and compliance
/// - Vehicle type determines delivery capacity and pricing
///
/// **Usage Example:**
/// ```dart
/// // Create vehicle for motorcycle driver
/// final vehicle = VehicleInfo(
///   plate: 'ABC-123-XY',
///   type: VehicleType.motorcycle,
///   make: 'Bajaj',
///   model: 'Boxer',
///   year: 2021,
///   color: 'Black',
/// );
///
/// // Display vehicle info
/// print(vehicle.displayName); // "2021 Bajaj Boxer (Black)"
///
/// // Update vehicle color
/// final updatedVehicle = vehicle.copyWith(color: 'Red');
///
/// // Invalid vehicle - throws ValidationException
/// try {
///   VehicleInfo(
///     plate: '', // Empty plate
///     type: VehicleType.car,
///     make: 'Toyota',
///     model: 'Corolla',
///     year: 2020,
///     color: 'Silver',
///   );
/// } catch (e) {
///   print(e); // ValidationException: Plate number cannot be empty
/// }
/// ```
///
/// **IMPROVEMENT:**
/// - [High Priority] Add plate number format validation (Nigerian format)
/// - [Medium Priority] Add vehicle registration number
/// - [Medium Priority] Add insurance details (policy number, expiry)
/// - [Low Priority] Add vehicle capacity (max weight, dimensions)
/// - [Low Priority] Add vehicle photo URLs
class VehicleInfo extends Equatable {
  /// Vehicle license plate number (validated: non-empty, trimmed)
  ///
  /// **Examples:**
  /// - Nigerian format: ABC-123-XY, LAG-456-ZZ
  /// - Required for vehicle identification
  final String plate;

  /// Vehicle type category
  ///
  /// **Supported types:**
  /// - motorcycle: Fast delivery, small packages
  /// - car: Standard delivery
  /// - van: Large packages
  /// - bicycle: Eco-friendly, short distance
  final VehicleType type;

  /// Vehicle manufacturer/brand (validated: non-empty, trimmed)
  ///
  /// **Examples:**
  /// - Motorcycle: Bajaj, Honda, TVS, Suzuki
  /// - Car: Toyota, Honda, Nissan, Hyundai
  /// - Van: Toyota, Mercedes, Volkswagen
  final String make;

  /// Vehicle model name (validated: non-empty, trimmed)
  ///
  /// **Examples:**
  /// - Motorcycle: Boxer, CBR, Apache
  /// - Car: Corolla, Civic, Altima, Elantra
  /// - Van: HiAce, Sprinter, Transporter
  final String model;

  /// Vehicle manufacturing year (validated: 1990 to current year + 1)
  ///
  /// **Validation:**
  /// - Minimum: 1990 (no vehicles older than 1990)
  /// - Maximum: Next year (allows new model year)
  ///
  /// **Why limit:**
  /// - Too old: Safety and insurance concerns
  /// - Future year: Prevents invalid data entry
  final int year;

  /// Vehicle color (validated: non-empty, trimmed)
  ///
  /// **Examples:** Black, White, Silver, Red, Blue, Green
  /// **Purpose:** Vehicle identification, customer recognition
  final String color;

  const VehicleInfo._({
    required this.plate,
    required this.type,
    required this.make,
    required this.model,
    required this.year,
    required this.color,
  });

  /// Creates a VehicleInfo with comprehensive validation
  ///
  /// **What it does:**
  /// - Validates all vehicle fields against business rules
  /// - Trims whitespace from string fields
  /// - Validates year range (1990 to next year)
  /// - Returns validated VehicleInfo instance
  ///
  /// **Validation performed:**
  /// 1. Plate number: non-empty, trimmed
  /// 2. Make: non-empty, trimmed
  /// 3. Model: non-empty, trimmed
  /// 4. Color: non-empty, trimmed
  /// 5. Year: 1990 to (current year + 1)
  /// 6. Type: valid VehicleType enum
  ///
  /// **Throws:**
  /// - [ValidationException]: If any field validation fails
  ///
  /// **Parameters:**
  /// - [plate]: Vehicle plate number (required, validated)
  /// - [type]: Vehicle type (required)
  /// - [make]: Vehicle make/brand (required, validated)
  /// - [model]: Vehicle model (required, validated)
  /// - [year]: Manufacturing year (required, validated)
  /// - [color]: Vehicle color (required, validated)
  ///
  /// **Example:**
  /// ```dart
  /// // Valid vehicle - succeeds
  /// final vehicle = VehicleInfo(
  ///   plate: 'LAG-123-AB',
  ///   type: VehicleType.motorcycle,
  ///   make: 'Bajaj',
  ///   model: 'Boxer',
  ///   year: 2020,
  ///   color: 'Black',
  /// );
  ///
  /// // Invalid plate - throws ValidationException
  /// VehicleInfo(
  ///   plate: '',  // Empty
  ///   ...
  /// ); // throws ValidationException
  ///
  /// // Invalid year - throws ValidationException
  /// VehicleInfo(
  ///   year: 1985,  // < 1990
  ///   ...
  /// ); // throws ValidationException
  /// ```
  factory VehicleInfo({
    required String plate,
    required VehicleType type,
    required String make,
    required String model,
    required int year,
    required String color,
  }) {
    // Trim whitespace
    final trimmedPlate = plate.trim();
    final trimmedMake = make.trim();
    final trimmedModel = model.trim();
    final trimmedColor = color.trim();

    // Validate plate
    if (trimmedPlate.isEmpty) {
      throw const ValidationException(
        message: AppStrings.errorVehicleEmptyPlate,
        fieldErrors: {'plate': AppStrings.errorVehicleEmptyPlate},
      );
    }

    // Validate make
    if (trimmedMake.isEmpty) {
      throw const ValidationException(
        message: AppStrings.errorVehicleEmptyMake,
        fieldErrors: {'make': AppStrings.errorVehicleEmptyMake},
      );
    }

    // Validate model
    if (trimmedModel.isEmpty) {
      throw const ValidationException(
        message: AppStrings.errorVehicleEmptyModel,
        fieldErrors: {'model': AppStrings.errorVehicleEmptyModel},
      );
    }

    // Validate color
    if (trimmedColor.isEmpty) {
      throw const ValidationException(
        message: AppStrings.errorVehicleEmptyColor,
        fieldErrors: {'color': AppStrings.errorVehicleEmptyColor},
      );
    }

    // Validate year (1990 to next year for new models)
    final currentYear = DateTime.now().year;
    if (year < 1990 || year > currentYear + 1) {
      throw const ValidationException(
        message: AppStrings.errorVehicleInvalidYear,
        fieldErrors: {'year': AppStrings.errorVehicleInvalidYear},
      );
    }

    return VehicleInfo._(
      plate: trimmedPlate,
      type: type,
      make: trimmedMake,
      model: trimmedModel,
      year: year,
      color: trimmedColor,
    );
  }

  /// Returns formatted vehicle display name
  ///
  /// **Format:** "{year} {make} {model} ({color})"
  ///
  /// **Examples:**
  /// - "2020 Toyota Corolla (Silver)"
  /// - "2021 Bajaj Boxer (Black)"
  /// - "2019 Honda HiAce (White)"
  ///
  /// **Usage:**
  /// - Driver profile display
  /// - Vehicle selection dropdown
  /// - Order details (show assigned driver's vehicle)
  /// - Admin dashboard
  String get displayName => '$year $make $model ($color)';

  /// Creates a copy of this vehicle with specified fields replaced
  ///
  /// **What it does:**
  /// - Creates new VehicleInfo instance with updated fields
  /// - Preserves unchanged fields from original
  /// - Re-runs validation on new field values
  /// - Enables immutable update pattern
  ///
  /// **Why immutable pattern:**
  /// - Prevents accidental mutations
  /// - Enables state comparison
  /// - Thread-safe
  /// - Aligns with value object principles
  ///
  /// **Parameters:** All optional, uses current value if not provided
  ///
  /// **Returns:** New VehicleInfo instance with updates
  ///
  /// **Example:**
  /// ```dart
  /// // Update vehicle color
  /// final recoloredVehicle = vehicle.copyWith(color: 'Red');
  ///
  /// // Update multiple fields
  /// final updatedVehicle = vehicle.copyWith(
  ///   year: 2022,
  ///   color: 'Blue',
  /// );
  /// ```
  VehicleInfo copyWith({
    String? plate,
    VehicleType? type,
    String? make,
    String? model,
    int? year,
    String? color,
  }) =>
      VehicleInfo(
        plate: plate ?? this.plate,
        type: type ?? this.type,
        make: make ?? this.make,
        model: model ?? this.model,
        year: year ?? this.year,
        color: color ?? this.color,
      );

  /// Equatable props for value comparison
  ///
  /// **Why all fields:**
  /// - Two vehicles are equal if ALL fields match
  /// - Used by Equatable for == operator and hashCode
  /// - Important for vehicle change detection
  @override
  List<Object?> get props => [plate, type, make, model, year, color];

  /// String representation for debugging
  ///
  /// **Format:** VehicleInfo(plate: ..., {displayName})
  ///
  /// **Example output:**
  /// "VehicleInfo(plate: LAG-123-AB, 2020 Toyota Corolla (Silver))"
  ///
  /// **Usage:**
  /// - Logging and debugging
  /// - Error messages
  /// - Development console output
  @override
  String toString() => 'VehicleInfo(plate: $plate, $displayName)';
}
