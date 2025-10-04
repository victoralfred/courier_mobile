import 'package:equatable/equatable.dart';
import 'package:delivery_app/core/constants/app_strings.dart';

/// Value object representing a validated email address
class Email extends Equatable {
  final String value;

  /// Creates an Email from a valid email string
  Email(String email) : value = _validate(email);

  /// Validates and normalizes the email string
  static String _validate(String email) {
    if (email.isEmpty) {
      throw ArgumentError(AppStrings.errorEmailEmpty);
    }

    // Trim whitespace
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError(AppStrings.errorEmailWhitespace);
    }

    // Normalize to lowercase
    final normalized = trimmed.toLowerCase();

    // Email regex pattern (simplified but covers most cases)
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(normalized)) {
      throw ArgumentError(
        AppStrings.format(AppStrings.errorInvalidEmailFormat, {'email': email}),
      );
    }

    // Additional validation checks
    if (normalized.contains('..')) {
      throw ArgumentError(AppStrings.errorEmailConsecutiveDots);
    }

    if (normalized.endsWith('.')) {
      throw ArgumentError(AppStrings.errorEmailEndsWithDot);
    }

    return normalized;
  }

  /// Gets the domain part of the email
  String get domain {
    final parts = value.split('@');
    return parts.last;
  }

  /// Gets the local part (username) of the email
  String get localPart {
    final parts = value.split('@');
    return parts.first;
  }

  @override
  String toString() => value;

  @override
  List<Object> get props => [value];
}