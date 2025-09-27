import 'package:equatable/equatable.dart';

/// Value object representing a validated email address
class Email extends Equatable {
  final String value;

  /// Creates an Email from a valid email string
  Email(String email) : value = _validate(email);

  /// Validates and normalizes the email string
  static String _validate(String email) {
    if (email.isEmpty) {
      throw ArgumentError('Email cannot be empty');
    }

    // Trim whitespace
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Email cannot be empty or whitespace');
    }

    // Normalize to lowercase
    final normalized = trimmed.toLowerCase();

    // Email regex pattern (simplified but covers most cases)
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(normalized)) {
      throw ArgumentError('Invalid email format: $email');
    }

    // Additional validation checks
    if (normalized.contains('..')) {
      throw ArgumentError('Email cannot contain consecutive dots');
    }

    if (normalized.endsWith('.')) {
      throw ArgumentError('Email cannot end with a dot');
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