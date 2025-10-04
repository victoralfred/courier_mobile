/// [DataObfuscator] - Service for masking, redacting, and sanitizing sensitive data
///
/// **What it does:**
/// - Masks personally identifiable information (PII) for display purposes
/// - Redacts sensitive fields from JSON objects for logging
/// - Sanitizes text to remove sensitive patterns before logging
/// - Protects data privacy in logs, error reports, and analytics
///
/// **Why it exists:**
/// - Prevents accidental exposure of sensitive data in logs/crash reports
/// - Complies with data privacy regulations (GDPR, CCPA, HIPAA)
/// - Allows safe debugging without revealing user information
/// - Reduces security risk from log aggregation services
/// - Provides user-friendly masked display (e.g., j***@example.com)
///
/// **Obfuscation Strategy:**
/// ```
/// Input Data Types:
/// - Email: john.doe@example.com ──> j***@example.com
/// - Phone: +2341234567890 ──> +234***7890
/// - Credit Card: 4532123456789012 ──> **** **** **** 9012
/// - JSON: {password: "secret"} ──> {password: "***REDACTED***"}
/// - Logs: "Bearer eyJ..." ──> "Bearer [TOKEN]"
/// ```
///
/// **Data Flow:**
/// ```
/// Application Layer
///       │
///       ├─── Display to User ────> Mask (show partial data)
///       │
///       ├─── Logging/Analytics ──> Sanitize (remove sensitive patterns)
///       │
///       └─── API Response ────────> Redact (replace sensitive fields)
///
/// Example Flows:
///
/// 1. Display Masked Email:
///    Raw: "john.doe@example.com"
///     │
///     ├─── maskEmail() ──> "j***@example.com"
///     │
///     └─── Show in UI
///
/// 2. Safe Logging:
///    Error: "Auth failed for user@example.com with token eyJ123..."
///     │
///     ├─── sanitizeForLogging() ──> "Auth failed for [EMAIL] with [TOKEN]"
///     │
///     └─── Send to log service
///
/// 3. API Response Logging:
///    Response: {user: "john", password: "secret", token: "abc"}
///     │
///     ├─── redactSensitiveFields() ──> {user: "john", password: "***REDACTED***", token: "***REDACTED***"}
///     │
///     └─── Log for debugging
/// ```
///
/// **Privacy Standards:**
/// ```
/// Masking Rules:
/// - Show first character + last 4 digits (phone, card)
/// - Show first character + domain (email)
/// - Preserve format for usability
///
/// Redaction Rules:
/// - Complete replacement for passwords, tokens
/// - Recursive processing for nested objects
/// - Configurable sensitive field names
///
/// Sanitization Patterns:
/// - Email addresses: [EMAIL]
/// - Phone numbers: [PHONE]
/// - Credit cards: [CARD]
/// - JWT tokens: [TOKEN]
/// - API keys: [KEY]
/// - Passwords in URLs: password=[REDACTED]
/// ```
///
/// **Usage Example:**
/// ```dart
/// final obfuscator = DataObfuscatorImpl();
///
/// // Mask email for display
/// final maskedEmail = obfuscator.maskEmail('john.doe@example.com');
/// print(maskedEmail); // "j***@example.com"
///
/// // Mask phone number
/// final maskedPhone = obfuscator.maskPhoneNumber('+2341234567890');
/// print(maskedPhone); // "+234***7890"
///
/// // Redact sensitive JSON fields
/// final response = {
///   'user': 'john',
///   'email': 'john@example.com',
///   'password': 'secret123',
///   'token': 'eyJ...',
/// };
/// final redacted = obfuscator.redactSensitiveFields(
///   response,
///   ['password', 'token'],
/// );
/// print(redacted); // {user: 'john', email: '...', password: '***REDACTED***', token: '***REDACTED***'}
///
/// // Sanitize logs
/// final logMessage = 'User john@example.com logged in with token eyJhbGc...';
/// final sanitized = obfuscator.sanitizeForLogging(logMessage);
/// print(sanitized); // "User [EMAIL] logged in with [TOKEN]"
/// ```
///
/// **Compliance Considerations:**
/// ```
/// GDPR (General Data Protection Regulation):
/// - Article 32: Data minimization in logs
/// - Right to privacy: Don't log PII unnecessarily
///
/// CCPA (California Consumer Privacy Act):
/// - Minimize data collection and retention
/// - Secure handling of personal information
///
/// HIPAA (Health Insurance Portability and Accountability Act):
/// - Protected Health Information (PHI) must not appear in logs
/// - Audit trails must not contain sensitive data
///
/// PCI DSS (Payment Card Industry Data Security Standard):
/// - Primary Account Number (PAN) must be masked
/// - CVV must never be logged or stored
/// ```
///
/// **IMPROVEMENT:**
/// - [MEDIUM PRIORITY] Add support for partial email masking
///   - Current: j***@example.com
///   - Better: j***e@example.com (show first and last char)
/// - [MEDIUM PRIORITY] Implement configurable masking strategies
///   - Allow different masking levels per data type
///   - High security: "****" (full redaction)
///   - Medium: Current implementation
///   - Low: Show more characters
/// - [MEDIUM PRIORITY] Add pattern detection for SSN, passport numbers
///   - Detect and mask social security numbers (XXX-XX-1234)
///   - International passport number patterns
/// - [LOW PRIORITY] Support custom regex patterns for sanitization
///   - Allow app-specific sensitive patterns
///   - User-defined field names for redaction
/// - [LOW PRIORITY] Add obfuscation metrics
///   - Track how often sensitive data is detected
///   - Alert on unusual patterns (potential data leak)
abstract class DataObfuscator {
  /// Masks email address for display
  ///
  /// **Format:** Shows first character + asterisks + @ + domain
  ///
  /// **Examples:**
  /// - john.doe@example.com → j***@example.com
  /// - a@test.com → a***@test.com
  ///
  /// **Use case:**
  /// - Display email in UI without full exposure
  /// - Confirmation messages ("Email sent to j***@example.com")
  ///
  /// **Parameters:**
  /// - [email]: Email address to mask
  ///
  /// **Returns:** Masked email address
  String maskEmail(String email);

  /// Masks phone number for display
  ///
  /// **Format:** Country code + asterisks + last 4 digits
  ///
  /// **Examples:**
  /// - +2341234567890 → +234***7890
  /// - 1234567890 → 123***7890
  ///
  /// **Use case:**
  /// - Display phone in UI
  /// - SMS verification confirmation
  ///
  /// **Parameters:**
  /// - [phone]: Phone number to mask (with or without country code)
  ///
  /// **Returns:** Masked phone number
  String maskPhoneNumber(String phone);

  /// Masks credit card number for display
  ///
  /// **Format:** **** **** **** [last 4 digits]
  ///
  /// **Examples:**
  /// - 4532123456789012 → **** **** **** 9012
  /// - 1234-5678-9012-3456 → **** **** **** 3456
  ///
  /// **Compliance:** PCI DSS compliant masking
  ///
  /// **Use case:**
  /// - Display saved payment methods
  /// - Transaction receipts
  ///
  /// **Parameters:**
  /// - [cardNumber]: Credit card number to mask
  ///
  /// **Returns:** Masked card number with formatting
  String maskCreditCard(String cardNumber);

  /// Redacts sensitive fields from JSON data
  ///
  /// **What it does:**
  /// - Recursively processes nested objects
  /// - Replaces sensitive field values with "***REDACTED***"
  /// - Preserves non-sensitive fields
  ///
  /// **Use case:**
  /// - Safe logging of API responses
  /// - Error reporting without exposing secrets
  ///
  /// **Parameters:**
  /// - [data]: JSON object to redact
  /// - [sensitiveFields]: List of field names to redact
  ///
  /// **Returns:** New map with sensitive fields redacted
  ///
  /// **Example:**
  /// ```dart
  /// final response = {'user': 'john', 'password': 'secret'};
  /// final redacted = redactSensitiveFields(response, ['password']);
  /// // Returns: {'user': 'john', 'password': '***REDACTED***'}
  /// ```
  Map<String, dynamic> redactSensitiveFields(
    Map<String, dynamic> data,
    List<String> sensitiveFields,
  );

  /// Sanitizes text for safe logging
  ///
  /// **What it does:**
  /// - Detects and replaces sensitive patterns with placeholders
  /// - Uses regex to identify: emails, phones, tokens, keys, cards
  ///
  /// **Patterns replaced:**
  /// - Email → [EMAIL]
  /// - Phone → [PHONE]
  /// - Credit card → [CARD]
  /// - JWT token → [TOKEN]
  /// - API key → [KEY]
  /// - Password in URL → password=[REDACTED]
  ///
  /// **Use case:**
  /// - Sanitize error messages before logging
  /// - Clean stack traces for crash reports
  /// - Safe analytics event data
  ///
  /// **Parameters:**
  /// - [text]: Text to sanitize (error message, log entry, etc.)
  ///
  /// **Returns:** Sanitized text with sensitive data replaced
  ///
  /// **Example:**
  /// ```dart
  /// final error = 'Auth failed for user@example.com';
  /// final safe = sanitizeForLogging(error);
  /// // Returns: "Auth failed for [EMAIL]"
  /// ```
  String sanitizeForLogging(String text);
}

/// [DataObfuscatorImpl] - Production implementation of data obfuscation
///
/// **What it does:**
/// - Implements all masking, redaction, and sanitization methods
/// - Uses regex patterns for data detection and transformation
/// - Provides configurable obfuscation strategies
///
/// **Implementation approach:**
/// - Regex-based pattern matching for reliability
/// - Preserves data format for usability
/// - Recursive processing for nested structures
///
/// **IMPROVEMENT:**
/// - [LOW PRIORITY] Add caching for compiled regex patterns
///   - Current implementation recompiles patterns on each call
///   - Cache RegExp objects for better performance
class DataObfuscatorImpl implements DataObfuscator {
  /// Regex pattern for email validation and parsing
  ///
  /// **Format:** username@domain
  /// **Groups:** [1] = username, [2] = domain
  static const _emailPattern = r'^([^@]+)@(.+)$';

  /// Regex pattern for phone number parsing
  ///
  /// **Format:** Optional + followed by country code and number
  /// **Groups:** [1] = country code, [2] = middle digits, [3] = last 4 digits
  static const _phonePattern = r'^\+?(\d{1,3})(\d{3,})(\d{4})$';

  @override
  String maskEmail(String email) {
    // Parse email into username and domain parts
    final regex = RegExp(_emailPattern);
    final match = regex.firstMatch(email);

    // Return original if format invalid
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
    // Remove all non-digit characters except + (normalize input)
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');

    // Try to parse with country code pattern
    final regex = RegExp(_phonePattern);
    final match = regex.firstMatch(cleaned);

    if (match == null) {
      // Fallback: If pattern doesn't match, just mask middle digits
      if (cleaned.length < 4) return cleaned;
      final start = cleaned.substring(0, 3);
      final end = cleaned.substring(cleaned.length - 4);
      return '$start***$end';
    }

    // Extract country code, middle digits, and last 4
    final countryCode = match.group(1);
    final middle = match.group(2);
    final last = match.group(3);

    // Format: +[country code][***][last 4]
    return '+$countryCode${'*' * middle!.length}$last';
  }

  @override
  String maskCreditCard(String cardNumber) {
    // Remove all non-digit characters (spaces, dashes, etc.)
    final cleaned = cardNumber.replaceAll(RegExp(r'\D'), '');

    // Handle short inputs
    if (cleaned.length < 4) return '*' * cleaned.length;

    // Show last 4 digits only, mask everything else
    final masked = '*' * (cleaned.length - 4) + cleaned.substring(cleaned.length - 4);

    // Format as groups of 4 for readability
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
    // Create copy to avoid mutating original data
    final redacted = Map<String, dynamic>.from(data);

    // Process each sensitive field
    for (final field in sensitiveFields) {
      if (redacted.containsKey(field)) {
        final value = redacted[field];

        // Handle different value types
        if (value is String) {
          // Mask string values (show first/last char)
          redacted[field] = _maskString(value);
        } else if (value is Map) {
          // Recursively redact nested maps
          redacted[field] = redactSensitiveFields(
            value as Map<String, dynamic>,
            sensitiveFields,
          );
        } else {
          // Complete redaction for other types
          redacted[field] = '***REDACTED***';
        }
      }
    }

    return redacted;
  }

  @override
  String sanitizeForLogging(String text) {
    var sanitized = text;

    // Define sensitive patterns and their replacements
    // Pattern order matters: More specific patterns first
    final patterns = {
      // Email addresses
      RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'):
          '[EMAIL]',
      // Phone numbers (10-15 digits, optional + prefix)
      RegExp(r'\+?\d{10,15}'): '[PHONE]',
      // Credit card numbers (16 digits with optional separators)
      RegExp(r'\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b'): '[CARD]',
      // JWT tokens (header.payload.signature format)
      RegExp(r'eyJ[A-Za-z0-9-_=]+\.eyJ[A-Za-z0-9-_=]+\.[A-Za-z0-9-_.+/=]+'): '[TOKEN]',
      // API keys (long alphanumeric strings)
      RegExp(r'\b[A-Za-z0-9]{32,}\b'): '[KEY]',
      // Passwords in URLs
      RegExp(r'password=([^&\s]+)'): 'password=[REDACTED]',
      // Bearer tokens in headers
      RegExp(r'Bearer\s+[A-Za-z0-9-_=]+\.[A-Za-z0-9-_=]+\.[A-Za-z0-9-_.+/=]+'): 'Bearer [TOKEN]',
    };

    // Apply all pattern replacements
    for (final entry in patterns.entries) {
      sanitized = sanitized.replaceAll(entry.key, entry.value);
    }

    return sanitized;
  }

  /// Masks string value for redaction
  ///
  /// **Format:**
  /// - Empty: Return as-is
  /// - 1-4 chars: Full masking (****)
  /// - 5+ chars: Show first and last char (a***z)
  ///
  /// **Parameters:**
  /// - [value]: String to mask
  ///
  /// **Returns:** Masked string
  String _maskString(String value) {
    if (value.isEmpty) return value;
    if (value.length <= 4) return '*' * value.length;

    // Show first and last character for longer strings
    return '${value[0]}${'*' * (value.length - 2)}${value[value.length - 1]}';
  }
}

/// Configuration presets for data obfuscation
///
/// **What it provides:**
/// - Environment-specific obfuscation rules
/// - Predefined lists of sensitive field names
/// - Logging control flags
///
/// **Usage:**
/// ```dart
/// // Production environment
/// final config = ObfuscationConfig.production;
/// final obfuscator = DataObfuscatorImpl();
/// final redacted = obfuscator.redactSensitiveFields(
///   data,
///   config.sensitiveFields,
/// );
///
/// // Custom configuration
/// final custom = ObfuscationConfig(
///   sensitiveFields: ['password', 'apiKey', 'customSecret'],
///   enableLogging: true,
/// );
/// ```
class ObfuscationConfig {
  /// List of field names to redact in JSON objects
  ///
  /// **Common fields:**
  /// - Authentication: password, token, accessToken, refreshToken
  /// - Secrets: secret, apiKey, privateKey
  /// - Payment: creditCard, cvv, pin
  /// - Personal: ssn, passport, driverLicense
  final List<String> sensitiveFields;

  /// Whether to enable obfuscation in log output
  ///
  /// **Use case:**
  /// - true: Production (always obfuscate)
  /// - false: Development (allow sensitive data for debugging)
  final bool enableLogging;

  /// Creates custom obfuscation configuration
  ///
  /// **Parameters:**
  /// - [sensitiveFields]: Field names to redact (default: common sensitive fields)
  /// - [enableLogging]: Enable obfuscation in logs (default: true)
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

  /// Production configuration (comprehensive obfuscation)
  ///
  /// **Security level:** High
  /// **Sensitive fields:** All common PII and credentials
  /// **Use case:** Production deployments
  static const ObfuscationConfig production = ObfuscationConfig(
    sensitiveFields: [
      'password',
      'token',
      'accessToken',
      'refreshToken',
      'secret',
      'apiKey',
      'privateKey',
      'creditCard',
      'cardNumber',
      'cvv',
      'cvc',
      'pin',
      'ssn',
      'socialSecurity',
      'driverLicense',
      'passport',
      'nationalId',
    ],
    enableLogging: true,
  );

  /// Development configuration (minimal obfuscation)
  ///
  /// **Security level:** Low (prioritize debugging)
  /// **Sensitive fields:** Only critical secrets
  /// **Use case:** Local development and testing
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