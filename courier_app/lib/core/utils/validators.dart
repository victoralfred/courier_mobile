/// Utility class for common validation functions
class Validators {
  // Private constructor to prevent instantiation
  Validators._();

  /// Email validation regex pattern
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  /// Phone validation regex pattern (supports international format)
  static final RegExp _phoneRegex = RegExp(
    r'^\+?[1-9]\d{1,14}$',
  );

  /// Check if an email is valid
  static bool isValidEmail(String email) {
    if (email.isEmpty) return false;
    return _emailRegex.hasMatch(email.trim());
  }

  /// Check if a phone number is valid
  static bool isValidPhone(String phone) {
    if (phone.isEmpty) return false;
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    return _phoneRegex.hasMatch(cleaned);
  }

  /// Check if a password is strong
  static bool isStrongPassword(String password) {
    if (password.length < 8) return false;

    final bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
    final bool hasLowercase = password.contains(RegExp(r'[a-z]'));
    final bool hasDigits = password.contains(RegExp(r'[0-9]'));
    final bool hasSpecialCharacters =
        password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    return hasUppercase && hasLowercase && hasDigits && hasSpecialCharacters;
  }

  /// Calculate password strength (0-4)
  static int getPasswordStrength(String password) {
    int strength = 0;

    if (password.length >= 8) strength++;
    if (password.length >= 12) strength++;
    if (password.contains(RegExp(r'[A-Z]')) &&
        password.contains(RegExp(r'[a-z]'))) {
      strength++;
    }
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength++;

    return strength > 4 ? 4 : strength;
  }

  /// Validate name (first or last)
  static bool isValidName(String name) {
    if (name.isEmpty) return false;
    final trimmed = name.trim();
    if (trimmed.length < 2 || trimmed.length > 50) return false;
    return RegExp(r"^[a-zA-Z\s\-']+$").hasMatch(trimmed);
  }

  /// Validate URL
  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (_) {
      return false;
    }
  }

  /// Validate Nigerian phone number specifically
  static bool isValidNigerianPhone(String phone) {
    if (phone.isEmpty) return false;
    // Remove spaces, dashes, and parentheses
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    // Check for Nigerian format: +234 or 0 followed by 10 digits
    return RegExp(r'^(\+234|234|0)[789][01]\d{8}$').hasMatch(cleaned);
  }

  /// Validate credit card number using Luhn algorithm
  static bool isValidCreditCard(String cardNumber) {
    if (cardNumber.isEmpty) return false;

    // Remove spaces and non-digits
    final cleaned = cardNumber.replaceAll(RegExp(r'\D'), '');

    if (cleaned.length < 13 || cleaned.length > 19) return false;

    // Luhn algorithm
    int sum = 0;
    bool isEven = false;

    for (int i = cleaned.length - 1; i >= 0; i--) {
      int digit = int.parse(cleaned[i]);

      if (isEven) {
        digit *= 2;
        if (digit > 9) {
          digit -= 9;
        }
      }

      sum += digit;
      isEven = !isEven;
    }

    return sum % 10 == 0;
  }

  /// Validate vehicle number (customizable per region)
  static bool isValidVehicleNumber(String vehicleNumber) {
    if (vehicleNumber.isEmpty) return false;
    // Example pattern for Nigerian vehicle numbers: ABC-123-XY
    return RegExp(r'^[A-Z]{2,3}-\d{3}-[A-Z]{2}$')
        .hasMatch(vehicleNumber.toUpperCase());
  }

  /// Validate driver license number
  static bool isValidLicenseNumber(String licenseNumber) {
    if (licenseNumber.isEmpty) return false;
    // Basic validation - alphanumeric with minimum length
    return RegExp(r'^[A-Z0-9]{6,20}$').hasMatch(licenseNumber.toUpperCase());
  }
}
