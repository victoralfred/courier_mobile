/// Vehicle type enumeration for Nigerian courier service
///
/// Defines supported vehicle types for delivery
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

extension VehicleTypeExtension on VehicleType {
  /// Convert enum to JSON string
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

  /// Get user-friendly display name
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

/// Helper class for VehicleType parsing
class VehicleTypeHelper {
  /// Parse vehicle type from string
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
