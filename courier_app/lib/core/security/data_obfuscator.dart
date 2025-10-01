/// Service for obfuscating sensitive data
/// Provides methods to mask, redact, and sanitize sensitive information
abstract class DataObfuscator {
  /// Mask email address (e.g., j***@example.com)
  String maskEmail(String email);

  /// Mask phone number (e.g., +234***1234)
  String maskPhoneNumber(String phone);

  /// Mask credit card number (e.g., **** **** **** 1234)
  String maskCreditCard(String cardNumber);

  /// Redact sensitive fields from JSON
  Map<String, dynamic> redactSensitiveFields(
    Map<String, dynamic> data,
    List<String> sensitiveFields,
  );

  /// Sanitize string for logging (remove sensitive patterns)
  String sanitizeForLogging(String text);
}

/// Implementation of DataObfuscator
class DataObfuscatorImpl implements DataObfuscator {
  static const _emailPattern = r'^([^@]+)@(.+)$';
  static const _phonePattern = r'^\+?(\d{1,3})(\d{3,})(\d{4})$';

  @override
  String maskEmail(String email) {
    final regex = RegExp(_emailPattern);
    final match = regex.firstMatch(email);

    if (match == null) return email;

    final username = match.group(1)!;
    final domain = match.group(2)!;

    // Show first character and mask the rest
    final maskedUsername = username.length > 1
        ? '${username[0]}${'*' * (username.length - 1)}'
        : username;

    return '$maskedUsername@$domain';
  }

  @override
  String maskPhoneNumber(String phone) {
    // Remove all non-digit characters except +
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');

    final regex = RegExp(_phonePattern);
    final match = regex.firstMatch(cleaned);

    if (match == null) {
      // If pattern doesn't match, just mask middle digits
      if (cleaned.length < 4) return cleaned;
      final start = cleaned.substring(0, 3);
      final end = cleaned.substring(cleaned.length - 4);
      return '$start***$end';
    }

    final countryCode = match.group(1);
    final middle = match.group(2);
    final last = match.group(3);

    return '+$countryCode${'*' * middle!.length}$last';
  }

  @override
  String maskCreditCard(String cardNumber) {
    // Remove all non-digit characters
    final cleaned = cardNumber.replaceAll(RegExp(r'\D'), '');

    if (cleaned.length < 4) return '*' * cleaned.length;

    // Show last 4 digits only
    final masked = '*' * (cleaned.length - 4) + cleaned.substring(cleaned.length - 4);

    // Format as groups of 4
    final formatted = StringBuffer();
    for (var i = 0; i < masked.length; i += 4) {
      if (i > 0) formatted.write(' ');
      final end = (i + 4 < masked.length) ? i + 4 : masked.length;
      formatted.write(masked.substring(i, end));
    }

    return formatted.toString();
  }

  @override
  Map<String, dynamic> redactSensitiveFields(
    Map<String, dynamic> data,
    List<String> sensitiveFields,
  ) {
    final redacted = Map<String, dynamic>.from(data);

    for (final field in sensitiveFields) {
      if (redacted.containsKey(field)) {
        final value = redacted[field];
        if (value is String) {
          redacted[field] = _maskString(value);
        } else if (value is Map) {
          redacted[field] = redactSensitiveFields(
            value as Map<String, dynamic>,
            sensitiveFields,
          );
        } else {
          redacted[field] = '***REDACTED***';
        }
      }
    }

    return redacted;
  }

  @override
  String sanitizeForLogging(String text) {
    var sanitized = text;

    // Remove common sensitive patterns
    final patterns = {
      // Email
      RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'):
          '[EMAIL]',
      // Phone
      RegExp(r'\+?\d{10,15}'): '[PHONE]',
      // Credit card (simple pattern)
      RegExp(r'\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b'): '[CARD]',
      // JWT tokens
      RegExp(r'eyJ[A-Za-z0-9-_=]+\.eyJ[A-Za-z0-9-_=]+\.[A-Za-z0-9-_.+/=]+'): '[TOKEN]',
      // API keys (common patterns)
      RegExp(r'\b[A-Za-z0-9]{32,}\b'): '[KEY]',
      // Passwords in URLs
      RegExp(r'password=([^&\s]+)'): 'password=[REDACTED]',
      // Bearer tokens
      RegExp(r'Bearer\s+[A-Za-z0-9-_=]+\.[A-Za-z0-9-_=]+\.[A-Za-z0-9-_.+/=]+'): 'Bearer [TOKEN]',
    };

    for (final entry in patterns.entries) {
      sanitized = sanitized.replaceAll(entry.key, entry.value);
    }

    return sanitized;
  }

  String _maskString(String value) {
    if (value.isEmpty) return value;
    if (value.length <= 4) return '*' * value.length;

    // Show first and last character
    return '${value[0]}${'*' * (value.length - 2)}${value[value.length - 1]}';
  }
}

/// Configuration for data obfuscation
class ObfuscationConfig {
  /// List of field names to redact in JSON
  final List<String> sensitiveFields;

  /// Whether to enable obfuscation in logs
  final bool enableLogging;

  const ObfuscationConfig({
    this.sensitiveFields = const [
      'password',
      'token',
      'accessToken',
      'refreshToken',
      'secret',
      'apiKey',
      'creditCard',
      'cvv',
      'pin',
      'ssn',
    ],
    this.enableLogging = true,
  });

  /// Production configuration (aggressive obfuscation)
  static const ObfuscationConfig production = ObfuscationConfig(
    sensitiveFields: [
      'password',
      'token',
      'accessToken',
      'refreshToken',
      'secret',
      'apiKey',
      'creditCard',
      'cardNumber',
      'cvv',
      'cvc',
      'pin',
      'ssn',
      'socialSecurity',
      'driverLicense',
      'passport',
    ],
    enableLogging: true,
  );

  /// Development configuration (minimal obfuscation)
  static const ObfuscationConfig development = ObfuscationConfig(
    sensitiveFields: [
      'password',
      'token',
      'secret',
      'apiKey',
    ],
    enableLogging: false,
  );
}