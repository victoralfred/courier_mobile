import 'package:equatable/equatable.dart';
import 'package:delivery_app/core/constants/app_strings.dart';

/// Value object representing a validated phone number
class PhoneNumber extends Equatable {
  final String value;

  /// Creates a PhoneNumber from a valid international phone number string
  PhoneNumber(String phone) : value = _validate(phone);

  /// Validates and normalizes the phone number string
  static String _validate(String phone) {
    if (phone.isEmpty) {
      throw ArgumentError(AppStrings.errorPhoneEmpty);
    }

    // Remove all formatting characters (spaces, dashes, parentheses)
    final normalized = phone
        .replaceAll(' ', '')
        .replaceAll('-', '')
        .replaceAll('(', '')
        .replaceAll(')', '')
        .replaceAll('.', '');

    // Must start with +
    if (!normalized.startsWith('+')) {
      throw ArgumentError(AppStrings.errorPhoneMissingCountryCode);
    }

    // Must contain only digits after the +
    final withoutPlus = normalized.substring(1);
    if (!RegExp(r'^\d+$').hasMatch(withoutPlus)) {
      throw ArgumentError(AppStrings.errorPhoneInvalidChars);
    }

    // Check length constraints (min 10 digits after +, max 20 total chars)
    // The minimum of 10 digits is for the actual phone number (not including +)
    if (withoutPlus.length < 10) {
      throw ArgumentError(AppStrings.errorPhoneTooShort);
    }

    if (normalized.length > 20) {
      throw ArgumentError(AppStrings.errorPhoneTooLong);
    }

    return normalized;
  }

  /// Gets the country code from the phone number
  String get countryCode {
    // Simple extraction - takes 1-3 digits after the +
    // More sophisticated logic would use a country code database
    final withoutPlus = value.substring(1);

    // Check common country codes
    if (withoutPlus.startsWith('1')) return '1';  // US, Canada
    if (withoutPlus.startsWith('44')) return '44';  // UK
    if (withoutPlus.startsWith('86')) return '86';  // China
    if (withoutPlus.startsWith('91')) return '91';  // India
    if (withoutPlus.startsWith('33')) return '33';  // France
    if (withoutPlus.startsWith('49')) return '49';  // Germany
    if (withoutPlus.startsWith('39')) return '39';  // Italy
    if (withoutPlus.startsWith('34')) return '34';  // Spain
    if (withoutPlus.startsWith('61')) return '61';  // Australia
    if (withoutPlus.startsWith('81')) return '81';  // Japan
    if (withoutPlus.startsWith('82')) return '82';  // South Korea
    if (withoutPlus.startsWith('55')) return '55';  // Brazil
    if (withoutPlus.startsWith('52')) return '52';  // Mexico
    if (withoutPlus.startsWith('234')) return '234';  // Nigeria
    if (withoutPlus.startsWith('254')) return '254';  // Kenya
    if (withoutPlus.startsWith('27')) return '27';  // South Africa
    if (withoutPlus.startsWith('971')) return '971';  // UAE
    if (withoutPlus.startsWith('966')) return '966';  // Saudi Arabia
    if (withoutPlus.startsWith('972')) return '972';  // Israel

    // Default: take first 1-3 digits
    if (withoutPlus.length >= 3) {
      // Try 3 digits first
      final threeDigit = withoutPlus.substring(0, 3);
      if (int.tryParse(threeDigit) != null) {
        return threeDigit;
      }
    }

    if (withoutPlus.length >= 2) {
      // Try 2 digits
      final twoDigit = withoutPlus.substring(0, 2);
      if (int.tryParse(twoDigit) != null) {
        return twoDigit;
      }
    }

    // Single digit country code
    return withoutPlus.substring(0, 1);
  }

  /// Returns the raw phone number without formatting
  String formatRaw() => value;

  /// Returns the phone number with international formatting
  String formatInternational() {
    final cc = countryCode;
    final withoutCountryCode = value.substring(1 + cc.length);

    // Format based on Nigerian phone number pattern
    // Nigerian numbers: +234 XXX XXX XXXX (for 10 digits after country code)
    // or +234 XX XXXX XXXX (for landlines)
    final buffer = StringBuffer('+$cc');

    if (withoutCountryCode.isNotEmpty) {
      buffer.write(' ');

      // For Nigerian numbers (country code 234)
      if (cc == '234' && withoutCountryCode.length == 10) {
        // Mobile format: +234 XXX XXX XXXX
        // Remove leading 0 if present (Nigerian numbers often written as 0803... locally)
        final digits = withoutCountryCode.startsWith('0')
            ? withoutCountryCode.substring(1)
            : withoutCountryCode;

        if (digits.length >= 10) {
          buffer.write(digits.substring(0, 3));
          buffer.write(' ');
          buffer.write(digits.substring(3, 6));
          buffer.write(' ');
          buffer.write(digits.substring(6));
        } else {
          buffer.write(digits);
        }
      } else if (cc == '234' && (withoutCountryCode.length == 8 || withoutCountryCode.length == 9)) {
        // Landline format: +234 XX XXXX XX(XX)
        buffer.write(withoutCountryCode.substring(0, 2));
        buffer.write(' ');
        buffer.write(withoutCountryCode.substring(2, 6));
        buffer.write(' ');
        buffer.write(withoutCountryCode.substring(6));
      } else {
        // For other numbers, use groups of 3
        for (int i = 0; i < withoutCountryCode.length; i++) {
          if (i > 0 && i % 3 == 0) {
            buffer.write(' ');
          }
          buffer.write(withoutCountryCode[i]);
        }
      }
    }

    return buffer.toString();
  }

  @override
  String toString() => value;

  @override
  List<Object> get props => [value];
}