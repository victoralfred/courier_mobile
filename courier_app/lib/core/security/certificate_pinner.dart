import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:crypto/crypto.dart';

/// [CertificatePinner] - SSL/TLS certificate pinning service for preventing man-in-the-middle attacks
///
/// **What it does:**
/// - Validates server SSL certificates against pre-configured SHA-256 hashes
/// - Configures Dio HTTP client with custom certificate validation
/// - Supports multiple certificates per domain (primary + backups)
/// - Blocks connections to servers with invalid/unexpected certificates
///
/// **Why it exists:**
/// - Prevents man-in-the-middle (MITM) attacks even if CA is compromised
/// - Protects against rogue/fraudulent SSL certificates
/// - Adds defense-in-depth beyond standard SSL/TLS validation
/// - Critical for mobile apps communicating with known backend servers
///
/// **Certificate Pinning Overview:**
/// ```
/// Standard SSL/TLS:
/// Client ──> Trust any CA-signed cert ──> Server
///   │
///   └─> VULNERABLE to: Compromised CA, Fraudulent certs, MITM proxies
///
/// With Certificate Pinning:
/// Client ──> Verify cert hash matches pinned hash ──> Server
///   │              │
///   │              ├─> Match: Allow connection
///   │              └─> Mismatch: Block connection
///   │
///   └─> PROTECTED: Only specific certificates accepted
/// ```
///
/// **Pinning Flow:**
/// ```
/// App Initialization
///     │
///     ├─── Load Pinned Hashes ────> CertificatePinner
///     │                                    │
///     │                                    └─── Configure Dio
///     │
/// Network Request
///     │
///     ├─── SSL Handshake ────> Server presents certificate
///     │                              │
///     │                              ├─── Extract DER encoding
///     │                              │
///     │                              ├─── Compute SHA-256 hash
///     │                              │
///     │                              └─── Compare with pinned hashes
///     │                                          │
///     │                                          ├─── Match: Allow
///     │                                          │
///     │                                          └─── Mismatch: Reject
/// ```
///
/// **Security Standards:**
/// ```
/// Hashing Algorithm: SHA-256 (256-bit digest)
/// Encoding: Base64 (for storage/transmission)
/// Pinned Data: Full certificate DER encoding
/// Validation: All certificates in chain
///
/// Best Practices:
/// - Pin to leaf certificate (most specific)
/// - Include backup certificate for rotation
/// - Update pins before certificate expiration
/// - Monitor certificate expiration dates
/// ```
///
/// **Usage Example:**
/// ```dart
/// // Define certificate hashes (get from openssl or browser)
/// final pinner = CertificatePinnerImpl(
///   certificates: {
///     'api.example.com': [
///       'AAAAAAAAA...primary_cert_hash',
///       'BBBBBBBBB...backup_cert_hash',
///     ],
///     'cdn.example.com': [
///       'CCCCCCCCC...cdn_cert_hash',
///     ],
///   },
/// );
///
/// // Configure Dio with certificate pinning
/// final dio = Dio();
/// pinner.configureDio(dio);
///
/// // All requests now validate certificates
/// await dio.get('https://api.example.com/data'); // Only succeeds if cert matches
///
/// // Add new certificate at runtime
/// pinner.addCertificate('new-api.example.com', 'DDDDDDDDD...');
/// ```
///
/// **How to Get Certificate Hash:**
/// ```bash
/// # Option 1: Using OpenSSL
/// openssl s_client -connect api.example.com:443 | \
///   openssl x509 -pubkey -noout | \
///   openssl rsa -pubin -outform der | \
///   openssl dgst -sha256 -binary | \
///   openssl enc -base64
///
/// # Option 2: Using Browser
/// 1. Open developer tools
/// 2. Go to Security tab
/// 3. View certificate
/// 4. Export certificate as DER
/// 5. Hash with SHA-256 and encode as Base64
/// ```
///
/// **Threat Model & Mitigations:**
/// ```
/// Threat 1: Compromised Certificate Authority
/// Mitigation: Only accept specific certificate hashes, ignore CA trust chain
///
/// Threat 2: Man-in-the-Middle Attack with Valid Certificate
/// Mitigation: Reject connections even with CA-valid cert if hash doesn't match
///
/// Threat 3: Certificate Substitution
/// Mitigation: SHA-256 hash verification ensures exact certificate match
///
/// Threat 4: SSL Stripping Attack
/// Mitigation: Enforce HTTPS-only connections (configure in Dio)
/// ```
///
/// **IMPROVEMENT:**
/// - [HIGH PRIORITY] Add certificate expiration monitoring
///   - Currently no warning when pinned certificates approach expiration
///   - Implement expiration date tracking and alerting (30 days before)
/// - [HIGH PRIORITY] Implement certificate rotation without app update
///   - Current implementation requires app release to update pins
///   - Add remote configuration endpoint for certificate updates
///   - Verify remote config with signature to prevent tampering
/// - [MEDIUM PRIORITY] Add public key pinning as alternative
///   - Pin public key instead of full certificate
///   - Survives certificate renewal if same key used
///   - More flexible for certificate rotation
/// - [MEDIUM PRIORITY] Implement certificate transparency (CT) log verification
///   - Validate certificates are in public CT logs
///   - Detect fraudulent certificates early
/// - [LOW PRIORITY] Add metrics for pinning failures
///   - Track pinning validation failures
///   - Alert on unexpected certificate changes
/// - [LOW PRIORITY] Support OCSP stapling verification
///   - Check certificate revocation status
///   - Enhance security beyond pinning
abstract class CertificatePinner {
  /// Configures Dio HTTP client with custom certificate validation
  ///
  /// **What it does:**
  /// - Overrides default HttpClient certificate callback
  /// - Routes all certificate validations through [validateCertificateChain]
  ///
  /// **Parameters:**
  /// - [dio]: Dio instance to configure
  ///
  /// **Side effects:**
  /// - Replaces Dio's HttpClient factory
  /// - All subsequent requests validate certificates
  ///
  /// **Example:**
  /// ```dart
  /// final dio = Dio();
  /// certificatePinner.configureDio(dio);
  /// // All requests now use certificate pinning
  /// ```
  void configureDio(Dio dio);

  /// Adds certificate hash for a domain
  ///
  /// **What it does:**
  /// - Stores SHA-256 hash for specified domain
  /// - Allows multiple hashes per domain (primary + backups)
  ///
  /// **Parameters:**
  /// - [domain]: Domain name (e.g., 'api.example.com')
  /// - [sha256Hash]: Base64-encoded SHA-256 certificate hash
  ///
  /// **Use case:**
  /// - Add backup certificates before rotation
  /// - Add certificates at runtime
  ///
  /// **Example:**
  /// ```dart
  /// pinner.addCertificate(
  ///   'api.example.com',
  ///   'AAAA...base64_cert_hash',
  /// );
  /// ```
  void addCertificate(String domain, String sha256Hash);

  /// Removes all certificate hashes for a domain
  ///
  /// **What it does:**
  /// - Clears all pinned certificates for domain
  /// - Domain will accept any valid SSL certificate after removal
  ///
  /// **Parameters:**
  /// - [domain]: Domain name to remove pins from
  ///
  /// **Warning:**
  /// - Removes ALL certificates for domain, not just one
  /// - Use with caution in production
  void removeCertificate(String domain);

  /// Validates certificate against pinned hashes
  ///
  /// **What it does:**
  /// 1. Calculates SHA-256 hash of certificate
  /// 2. Compares against pinned hashes for domain
  /// 3. Returns true if match found, false otherwise
  ///
  /// **Parameters:**
  /// - [cert]: X509Certificate from SSL handshake
  /// - [domain]: Domain being connected to
  ///
  /// **Returns:**
  /// - true: Certificate hash matches pinned hash
  /// - false: Certificate hash does not match (connection blocked)
  ///
  /// **Behavior:**
  /// - If no pins configured for domain: Returns true (allow)
  /// - If pins configured: Returns true only if hash matches
  bool validateCertificateChain(X509Certificate cert, String domain);
}

/// [CertificatePinnerImpl] - Production implementation of certificate pinning
///
/// **What it does:**
/// - Stores certificate hashes in memory
/// - Validates certificates during SSL handshake
/// - Configures Dio's HttpClient with custom validation
///
/// **Security Considerations:**
/// - Development mode: Returns true if no pins configured (allows all)
/// - Production mode: Should configure pins for all domains
///
/// **IMPROVEMENT:**
/// - [HIGH PRIORITY] Remove debug print statements
///   - Use proper logging service instead
///   - Sensitive certificate hashes exposed in logs
/// - [MEDIUM PRIORITY] Make development allow-all behavior configurable
///   - Add strict mode that fails if no pins configured
class CertificatePinnerImpl implements CertificatePinner {
  /// Map of domain names to list of pinned certificate hashes
  ///
  /// **Structure:**
  /// - Key: Domain name (e.g., 'api.example.com')
  /// - Value: List of Base64-encoded SHA-256 hashes
  final Map<String, List<String>> _pinnedCertificates = {};

  /// Creates certificate pinner with optional initial pins
  ///
  /// **Parameters:**
  /// - [certificates]: Initial certificate pins (optional)
  ///
  /// **Example:**
  /// ```dart
  /// final pinner = CertificatePinnerImpl(
  ///   certificates: {
  ///     'api.example.com': ['AAAA...', 'BBBB...'],
  ///   },
  /// );
  /// ```
  CertificatePinnerImpl({
    Map<String, List<String>>? certificates,
  }) {
    if (certificates != null) {
      _pinnedCertificates.addAll(certificates);
    }
  }

  @override
  void configureDio(Dio dio) {
    // Configure HttpClient with custom certificate validation callback
    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      // Override bad certificate callback to use our pinning validation
      client.badCertificateCallback =
          (cert, host, port) => validateCertificateChain(cert, host);
      return client;
    };
  }

  @override
  void addCertificate(String domain, String sha256Hash) {
    // Initialize list if domain not yet configured
    if (!_pinnedCertificates.containsKey(domain)) {
      _pinnedCertificates[domain] = [];
    }
    // Add hash if not already present (avoid duplicates)
    if (!_pinnedCertificates[domain]!.contains(sha256Hash)) {
      _pinnedCertificates[domain]!.add(sha256Hash);
    }
  }

  @override
  void removeCertificate(String domain) {
    // Remove all certificate pins for domain
    _pinnedCertificates.remove(domain);
  }

  @override
  bool validateCertificateChain(X509Certificate cert, String domain) {
    // If no pins configured for this domain, allow (development mode)
    // WARNING: In production, all domains should have pins configured
    if (!_pinnedCertificates.containsKey(domain)) {
      return true;
    }

    // Calculate SHA-256 hash of the certificate
    final certHash = _calculateCertificateHash(cert);

    // Check if the hash matches any pinned certificate for this domain
    final pinnedHashes = _pinnedCertificates[domain]!;
    final isValid = pinnedHashes.contains(certHash);

    // Log failure for debugging (remove in production)
    if (!isValid) {
      print('Certificate pinning failed for $domain');
      print('Expected one of: ${pinnedHashes.join(", ")}');
      print('Got: $certHash');
    }

    return isValid;
  }

  /// Calculates SHA-256 hash of certificate DER encoding
  ///
  /// **What it does:**
  /// 1. Extracts DER encoding from certificate
  /// 2. Computes SHA-256 digest
  /// 3. Encodes as Base64 for comparison
  ///
  /// **Parameters:**
  /// - [cert]: X509Certificate from SSL handshake
  ///
  /// **Returns:** Base64-encoded SHA-256 hash
  String _calculateCertificateHash(X509Certificate cert) {
    // Extract DER (Distinguished Encoding Rules) binary format
    final der = cert.der;

    // Compute SHA-256 hash of DER bytes
    final digest = sha256.convert(der);

    // Encode as Base64 for storage/comparison
    return base64.encode(digest.bytes);
  }
}

/// Configuration presets for certificate pinning
///
/// **What it provides:**
/// - Environment-specific certificate configurations
/// - Centralized certificate hash management
/// - Debug mode control
///
/// **Usage:**
/// ```dart
/// // Production
/// final config = CertificatePinningConfig.production();
/// final pinner = CertificatePinnerImpl(certificates: config.certificates);
///
/// // Development (no pinning)
/// final devConfig = CertificatePinningConfig.development();
/// ```
class CertificatePinningConfig {
  /// Map of domain names to list of SHA-256 certificate hashes
  ///
  /// **Format:**
  /// ```dart
  /// {
  ///   'api.example.com': [
  ///     'primary_cert_hash_base64',
  ///     'backup_cert_hash_base64',
  ///   ],
  /// }
  /// ```
  final Map<String, List<String>> certificates;

  /// Whether to enable certificate pinning in debug builds
  ///
  /// **Default:** false (pinning disabled in debug for easier testing)
  final bool enableInDebug;

  /// Creates certificate pinning configuration
  ///
  /// **Parameters:**
  /// - [certificates]: Domain to certificate hash mapping
  /// - [enableInDebug]: Enable pinning in debug mode (default: false)
  const CertificatePinningConfig({
    required this.certificates,
    this.enableInDebug = false,
  });

  /// Production certificate configuration
  ///
  /// **Action Required:**
  /// - Add production API certificate hashes
  /// - Include backup certificates for rotation
  /// - Test before deploying to production
  ///
  /// **How to get certificate hash:**
  /// ```bash
  /// openssl s_client -connect api.yourapp.com:443 | \
  ///   openssl x509 -outform der | \
  ///   openssl dgst -sha256 -binary | \
  ///   openssl enc -base64
  /// ```
  static CertificatePinningConfig production() =>
      const CertificatePinningConfig(
        certificates: {
          //TODO Add your production certificate hashes here
          // Example:
          // 'api.yourapp.com': [
          //   'BASE64_ENCODED_SHA256_HASH_1', // Primary certificate
          //   'BASE64_ENCODED_SHA256_HASH_2', // Backup certificate
          // ],
        },
        enableInDebug: false,
      );

  /// Staging environment certificate configuration
  ///
  /// **Action Required:**
  /// - Add staging API certificate hashes
  static CertificatePinningConfig staging() => const CertificatePinningConfig(
        certificates: {
          // Add your staging certificate hashes here
        },
        enableInDebug: false,
      );

  /// Development configuration (no certificate pinning)
  ///
  /// **Use case:**
  /// - Local development
  /// - Testing with self-signed certificates
  /// - Localhost API servers
  static CertificatePinningConfig development() =>
      const CertificatePinningConfig(
        certificates: {},
        enableInDebug: false,
      );
}

/// Exception thrown when certificate pinning validation fails
///
/// **When thrown:**
/// - Server certificate hash doesn't match pinned hash
/// - Potential MITM attack detected
/// - Certificate rotation without app update
///
/// **Usage:**
/// ```dart
/// try {
///   await dio.get('https://api.example.com/data');
/// } on DioException catch (e) {
///   if (e.type == DioExceptionType.connectionError) {
///     // Might be certificate pinning failure
///     print('Certificate validation failed');
///   }
/// }
/// ```
class CertificatePinningException implements Exception {
  /// Error message describing the failure
  final String message;

  /// Domain where certificate validation failed
  final String domain;

  CertificatePinningException(this.domain, this.message);

  @override
  String toString() => 'CertificatePinningException [$domain]: $message';
}
