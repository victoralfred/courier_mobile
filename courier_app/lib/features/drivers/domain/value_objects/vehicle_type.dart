/// [VehicleType] - Enum value object representing vehicle category for deliveries
///
/// **What it does:**
/// - Defines supported vehicle types for delivery service
/// - Categorizes vehicles by capacity and delivery use case
/// - Enables type-specific pricing and routing
/// - Type-safe vehicle categorization
///
/// **Why it exists:**
/// - Different vehicle types have different delivery capabilities
/// - Enables capacity-based order assignment
/// - Supports type-specific pricing (motorcycle vs van)
/// - Filters drivers by vehicle type for specific orders
/// - Nigerian courier context (popular vehicle types)
///
/// **Business Context:**
/// - **Motorcycle (Okada)**: Most common in Nigeria, fast navigation through traffic
/// - **Car**: Standard delivery, balanced capacity and speed
/// - **Van**: Large packages, commercial deliveries
/// - **Bicycle**: Eco-friendly, urban short-distance delivery
///
/// **Use Cases:**
/// - Order assignment (match package size to vehicle type)
/// - Pricing calculation (motorcycle cheaper than van)
/// - Driver filtering (show only motorcycle drivers for small packages)
/// - Capacity planning (van required for bulk orders)
///
/// **Usage Example:**
/// ```dart
/// // Create vehicle with type
/// final vehicle = VehicleInfo(
///   plate: 'LAG-123-AB',
///   type: VehicleType.motorcycle,
///   make: 'Bajaj',
///   model: 'Boxer',
///   year: 2021,
///   color: 'Black',
/// );
///
/// // Filter drivers by vehicle type
/// final motorcycleDrivers = allDrivers
///     .where((d) => d.vehicleInfo.type == VehicleType.motorcycle)
///     .toList();
///
/// // Type-specific logic
/// final deliveryFee = switch (vehicle.type) {
///   VehicleType.motorcycle => 500.0,
///   VehicleType.car => 1000.0,
///   VehicleType.van => 2000.0,
///   VehicleType.bicycle => 300.0,
/// };
/// ```
///
/// **IMPROVEMENT:**
/// - [Medium Priority] Add truck type (extra-large deliveries)
/// - [Low Priority] Add electric_vehicle type (eco-friendly fleet)
enum VehicleType {
  /// Motorcycle/Okada - Fast delivery for small packages
  motorcycle,

  /// Car - Standard delivery
  car,

  /// Van - Large package delivery
  van,

  /// Bicycle - Eco-friendly short distance delivery
  bicycle,
}

/// [VehicleTypeExtension] - Extension methods for VehicleType enum
///
/// **What it provides:**
/// - JSON serialization (toJson)
/// - User-friendly display names (displayName)
///
/// **Usage Example:**
/// ```dart
/// final type = VehicleType.motorcycle;
/// print(type.toJson()); // 'motorcycle'
/// print(type.displayName); // 'Motorcycle'
/// ```
extension VehicleTypeExtension on VehicleType {
  /// Converts enum to JSON string for API communication
  ///
  /// **Returns:** Lowercase string representation
  /// **Usage:** Serialization to backend API, local database
  ///
  /// **Examples:**
  /// - VehicleType.motorcycle → 'motorcycle'
  /// - VehicleType.car → 'car'
  /// - VehicleType.van → 'van'
  /// - VehicleType.bicycle → 'bicycle'
  String toJson() {
    switch (this) {
      case VehicleType.motorcycle:
        return 'motorcycle';
      case VehicleType.car:
        return 'car';
      case VehicleType.van:
        return 'van';
      case VehicleType.bicycle:
        return 'bicycle';
    }
  }

  /// Returns user-friendly display name for UI presentation
  ///
  /// **Returns:** Capitalized type name
  /// **Usage:** Vehicle type selector, driver profile, order details
  ///
  /// **Examples:**
  /// - VehicleType.motorcycle → 'Motorcycle'
  /// - VehicleType.car → 'Car'
  /// - VehicleType.van → 'Van'
  /// - VehicleType.bicycle → 'Bicycle'
  String get displayName {
    switch (this) {
      case VehicleType.motorcycle:
        return 'Motorcycle';
      case VehicleType.car:
        return 'Car';
      case VehicleType.van:
        return 'Van';
      case VehicleType.bicycle:
        return 'Bicycle';
    }
  }
}

/// [VehicleTypeHelper] - Helper class for VehicleType deserialization
///
/// **What it does:**
/// - Parses string values to VehicleType enum
/// - Handles case-insensitive parsing
/// - Validates vehicle type values
///
/// **Usage Example:**
/// ```dart
/// // Parse from API response
/// final type = VehicleTypeHelper.fromString('motorcycle');
///
/// // Case-insensitive
/// final type2 = VehicleTypeHelper.fromString('CAR');
///
/// // Invalid type throws error
/// try {
///   final invalid = VehicleTypeHelper.fromString('truck');
/// } catch (e) {
///   print('Invalid type: $e'); // ArgumentError
/// }
/// ```
class VehicleTypeHelper {
  /// Parses vehicle type from string (case-insensitive)
  ///
  /// **Parameters:**
  /// - [value]: Type string (e.g., 'motorcycle', 'car', 'VAN')
  ///
  /// **Returns:** Corresponding VehicleType enum value
  ///
  /// **Throws:**
  /// - ArgumentError: If value is not a valid vehicle type
  ///
  /// **Supported values:**
  /// - 'motorcycle' → VehicleType.motorcycle
  /// - 'car' → VehicleType.car
  /// - 'van' → VehicleType.van
  /// - 'bicycle' → VehicleType.bicycle
  static VehicleType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'motorcycle':
        return VehicleType.motorcycle;
      case 'car':
        return VehicleType.car;
      case 'van':
        return VehicleType.van;
      case 'bicycle':
        return VehicleType.bicycle;
      default:
        throw ArgumentError('Invalid vehicle type: $value');
    }
  }
}
