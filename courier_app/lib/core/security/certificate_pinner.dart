import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:crypto/crypto.dart';

/// Service for SSL certificate pinning
/// Validates server certificates against known SHA-256 hashes
abstract class CertificatePinner {
  /// Configure Dio client with certificate pinning
  void configureDio(Dio dio);

  /// Add a certificate hash for a domain
  void addCertificate(String domain, String sha256Hash);

  /// Remove a certificate hash for a domain
  void removeCertificate(String domain);

  /// Validate certificate chain
  bool validateCertificateChain(X509Certificate cert, String domain);
}

/// Implementation of CertificatePinner
class CertificatePinnerImpl implements CertificatePinner {
  final Map<String, List<String>> _pinnedCertificates = {};

  CertificatePinnerImpl({
    Map<String, List<String>>? certificates,
  }) {
    if (certificates != null) {
      _pinnedCertificates.addAll(certificates);
    }
  }

  @override
  void configureDio(Dio dio) {
    // Configure HttpClient with custom certificate validation
    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback =
          (cert, host, port) => validateCertificateChain(cert, host);
      return client;
    };
  }

  @override
  void addCertificate(String domain, String sha256Hash) {
    if (!_pinnedCertificates.containsKey(domain)) {
      _pinnedCertificates[domain] = [];
    }
    if (!_pinnedCertificates[domain]!.contains(sha256Hash)) {
      _pinnedCertificates[domain]!.add(sha256Hash);
    }
  }

  @override
  void removeCertificate(String domain) {
    _pinnedCertificates.remove(domain);
  }

  @override
  bool validateCertificateChain(X509Certificate cert, String domain) {
    // If no pins configured for this domain, allow (for development)
    if (!_pinnedCertificates.containsKey(domain)) {
      return true;
    }

    // Calculate SHA-256 hash of the certificate
    final certHash = _calculateCertificateHash(cert);

    // Check if the hash matches any pinned certificate for this domain
    final pinnedHashes = _pinnedCertificates[domain]!;
    final isValid = pinnedHashes.contains(certHash);

    if (!isValid) {
      print('Certificate pinning failed for $domain');
      print('Expected one of: ${pinnedHashes.join(", ")}');
      print('Got: $certHash');
    }

    return isValid;
  }

  /// Calculate SHA-256 hash of certificate DER encoding
  String _calculateCertificateHash(X509Certificate cert) {
    final der = cert.der;
    final digest = sha256.convert(der);
    return base64.encode(digest.bytes);
  }
}

/// Configuration for certificate pinning
class CertificatePinningConfig {
  /// Map of domain to list of SHA-256 certificate hashes
  final Map<String, List<String>> certificates;

  /// Whether to enable certificate pinning in debug mode
  final bool enableInDebug;

  const CertificatePinningConfig({
    required this.certificates,
    this.enableInDebug = false,
  });

  /// Production certificates configuration
  static CertificatePinningConfig production() =>
      const CertificatePinningConfig(
        certificates: {
          //TODO Add your production certificate hashes here
          // Example:
          // 'api.yourapp.com': [
          //   'BASE64_ENCODED_SHA256_HASH_1',
          //   'BASE64_ENCODED_SHA256_HASH_2', // Backup certificate
          // ],
        },
        enableInDebug: false,
      );

  /// Staging certificates configuration
  static CertificatePinningConfig staging() => const CertificatePinningConfig(
        certificates: {
          // Add your staging certificate hashes here
        },
        enableInDebug: false,
      );

  /// Development configuration (no pinning)
  static CertificatePinningConfig development() =>
      const CertificatePinningConfig(
        certificates: {},
        enableInDebug: false,
      );
}

/// Exception thrown when certificate pinning validation fails
class CertificatePinningException implements Exception {
  final String message;
  final String domain;

  CertificatePinningException(this.domain, this.message);

  @override
  String toString() => 'CertificatePinningException [$domain]: $message';
}
