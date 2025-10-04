/// Package size enumeration for Nigerian courier service
///
/// Defines standard package sizes for delivery items
enum PackageSize {
  /// Small packages (up to 2kg, < 30cm x 30cm x 30cm)
  /// Examples: Documents, phones, small electronics
  small,

  /// Medium packages (2-10kg, < 50cm x 50cm x 50cm)
  /// Examples: Clothing, books, small appliances
  medium,

  /// Large packages (10-25kg, < 100cm x 100cm x 100cm)
  /// Examples: Furniture parts, large electronics
  large,

  /// Extra large packages (25-50kg, < 150cm x 150cm x 150cm)
  /// Examples: Appliances, furniture
  xlarge,
}

extension PackageSizeExtension on PackageSize {
  /// Convert enum to JSON string
  String toJson() {
    switch (this) {
      case PackageSize.small:
        return 'small';
      case PackageSize.medium:
        return 'medium';
      case PackageSize.large:
        return 'large';
      case PackageSize.xlarge:
        return 'xlarge';
    }
  }
}

/// Helper class for PackageSize parsing
class PackageSizeHelper {
  /// Parse package size from string
  static PackageSize fromString(String value) {
    switch (value.toLowerCase()) {
      case 'small':
        return PackageSize.small;
      case 'medium':
        return PackageSize.medium;
      case 'large':
        return PackageSize.large;
      case 'xlarge':
        return PackageSize.xlarge;
      default:
        throw ArgumentError('Invalid package size: $value');
    }
  }
}
