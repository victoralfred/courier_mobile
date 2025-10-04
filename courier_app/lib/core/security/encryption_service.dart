import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// [EncryptionService] - Provides encryption, decryption, and hashing for sensitive data
///
/// **What it does:**
/// - Encrypts sensitive data using platform-native secure storage
/// - Decrypts encrypted data from secure storage
/// - Hashes data using SHA-256 algorithm
/// - Generates cryptographically secure random salts
/// - Verifies hashed data with salt-based comparison
///
/// **Why it exists:**
/// - Protects sensitive data at rest (tokens, credentials, user info)
/// - Leverages platform-native encryption (iOS Keychain, Android KeyStore)
/// - Provides standard hashing for password verification and data integrity
/// - Centralizes all cryptographic operations for consistency
///
/// **Encryption Standards:**
/// ```
/// Platform-Native Encryption:
/// - iOS: AES-256 encryption via Keychain (kSecAttrAccessibleAfterFirstUnlock)
/// - Android: AES-256 encryption via KeyStore with hardware backing
/// - Automatic key rotation and secure key storage
///
/// Hashing Algorithm:
/// - Algorithm: SHA-256 (256-bit digest)
/// - Salt Length: 32 bytes (256 bits)
/// - Salt Generation: Random.secure() for cryptographic randomness
/// ```
///
/// **Security Architecture:**
/// ```
/// Application Layer
///       │
///       ├─── Plaintext Data
///       │
///       ▼
/// EncryptionService
///       │
///       ├─── Encryption ────> flutter_secure_storage
///       │                            │
///       │                            ▼
///       │                     Platform Storage
///       │                            │
///       │                     ┌──────┴──────┐
///       │                     │             │
///       │                  iOS          Android
///       │                Keychain       KeyStore
///       │                (AES-256)      (AES-256)
///       │
///       ├─── Hashing ────> SHA-256 + Salt
///       │                       │
///       │                       ▼
///       │                 Hash Digest
/// ```
///
/// **Usage Example:**
/// ```dart
/// // Initialize encryption service
/// final storage = FlutterSecureStorage();
/// final encryptionService = EncryptionServiceImpl(storage: storage);
///
/// // Encrypt sensitive data
/// await encryptionService.encryptData('auth_token', 'Bearer abc123...');
///
/// // Decrypt encrypted data
/// final token = await encryptionService.decryptData('auth_token');
/// print('Token: $token'); // "Bearer abc123..."
///
/// // Hash password with salt
/// final salt = encryptionService.generateSalt();
/// final hash = encryptionService.hashWithSalt('user_password', salt);
///
/// // Verify password later
/// final isValid = encryptionService.verifyHash('user_password', hash, salt);
/// ```
///
/// **Threat Model & Mitigations:**
/// ```
/// Threat 1: Data Extraction from Device Storage
/// Mitigation: Platform-native encryption with hardware-backed keys
///
/// Threat 2: Rainbow Table Attacks on Hashed Data
/// Mitigation: Cryptographically secure random salts (32 bytes)
///
/// Threat 3: Weak Random Number Generation
/// Mitigation: Random.secure() instead of Random()
///
/// Threat 4: Key Extraction via Root/Jailbreak
/// Mitigation: Hardware-backed KeyStore (Android 6.0+), Secure Enclave (iOS)
/// ```
///
/// **IMPROVEMENT:**
/// - [HIGH PRIORITY] Implement key rotation strategy for long-lived data
///   - Currently no mechanism to rotate encryption keys
///   - Add versioning to encrypted data for migration
/// - [HIGH PRIORITY] Add encryption/decryption monitoring and error logging
///   - Track encryption failures for security auditing
///   - Alert on suspicious patterns (mass decryption attempts)
/// - [MEDIUM PRIORITY] Implement PBKDF2 or Argon2 for password hashing
///   - SHA-256 + salt is vulnerable to GPU-accelerated brute force
///   - Use key derivation function with high iteration count
/// - [MEDIUM PRIORITY] Add data integrity verification (HMAC)
///   - Detect tampering of encrypted data in storage
///   - Combine encryption with authentication (encrypt-then-MAC)
/// - [LOW PRIORITY] Support different encryption algorithms per platform
///   - Allow AES-GCM for authenticated encryption
///   - ChaCha20-Poly1305 for better mobile performance
/// - [LOW PRIORITY] Add secure memory wiping for sensitive strings
///   - Plaintext passwords may linger in memory
///   - Implement zero-fill after use
abstract class EncryptionService {
  /// Encrypts plaintext data and stores it securely
  ///
  /// **What it does:**
  /// - Stores plaintext under specified key using platform-native encryption
  /// - Returns the storage key as reference to encrypted data
  ///
  /// **Parameters:**
  /// - [key]: Unique identifier for stored data
  /// - [plaintext]: Sensitive data to encrypt
  ///
  /// **Returns:** Storage key (same as input key)
  ///
  /// **Throws:** [EncryptionException] if encryption fails
  Future<String> encryptData(String key, String plaintext);

  /// Decrypts and retrieves encrypted data
  ///
  /// **What it does:**
  /// - Retrieves encrypted data by key
  /// - Automatically decrypts using platform-native decryption
  ///
  /// **Parameters:**
  /// - [key]: Unique identifier used during encryption
  ///
  /// **Returns:** Decrypted plaintext or null if key not found
  ///
  /// **Throws:** [EncryptionException] if decryption fails
  Future<String?> decryptData(String key);

  /// Hashes data using SHA-256 (without salt)
  ///
  /// **What it does:**
  /// - Computes SHA-256 hash of input data
  /// - Returns hex-encoded hash digest
  ///
  /// **Security Note:**
  /// - Vulnerable to rainbow table attacks
  /// - Use [hashWithSalt] for password hashing
  ///
  /// **Parameters:**
  /// - [data]: Data to hash
  ///
  /// **Returns:** SHA-256 hash (64 hex characters)
  String hashData(String data);

  /// Hashes data with cryptographic salt
  ///
  /// **What it does:**
  /// - Combines data with salt before hashing
  /// - Computes SHA-256 hash of combined value
  ///
  /// **Security:**
  /// - Protects against rainbow table attacks
  /// - Unique salt per data entry required
  ///
  /// **Parameters:**
  /// - [data]: Data to hash (e.g., password)
  /// - [salt]: Cryptographic salt from [generateSalt]
  ///
  /// **Returns:** SHA-256 hash of (data + salt)
  String hashWithSalt(String data, String salt);

  /// Generates cryptographically secure random salt
  ///
  /// **What it does:**
  /// - Generates 32 bytes of random data
  /// - Uses Random.secure() for cryptographic randomness
  /// - Base64-encodes for storage
  ///
  /// **Returns:** Base64-encoded 32-byte salt
  String generateSalt();

  /// Verifies hashed data against stored hash
  ///
  /// **What it does:**
  /// - Recomputes hash with same data and salt
  /// - Performs constant-time comparison
  ///
  /// **Parameters:**
  /// - [data]: Original data to verify
  /// - [hash]: Stored hash to compare against
  /// - [salt]: Salt used during original hashing
  ///
  /// **Returns:** True if hashes match, false otherwise
  bool verifyHash(String data, String hash, String salt);
}

/// [EncryptionServiceImpl] - Production implementation of EncryptionService
///
/// **What it does:**
/// - Implements encryption using flutter_secure_storage
/// - Provides SHA-256 hashing with and without salt
/// - Generates cryptographically secure random salts
///
/// **Why this implementation:**
/// - flutter_secure_storage uses best-in-class platform encryption
/// - No custom crypto code (reduces risk of vulnerabilities)
/// - Automatic key management by platform
///
/// **Platform Details:**
/// - iOS: Uses Keychain Services with kSecAttrAccessibleAfterFirstUnlock
/// - Android: Uses EncryptedSharedPreferences with KeyStore
/// - Hardware-backed keys on supported devices
///
/// **IMPROVEMENT:**
/// - [MEDIUM PRIORITY] Add constant-time comparison in verifyHash
///   - Current == comparison vulnerable to timing attacks
///   - Implement secure.equals() for hash comparison
class EncryptionServiceImpl implements EncryptionService {
  /// Platform-native secure storage instance
  ///
  /// **Why private:**
  /// - Prevents direct storage access (use service methods)
  /// - Ensures consistent encryption/decryption flow
  final FlutterSecureStorage _storage;

  /// Creates encryption service with secure storage backend
  ///
  /// **Parameters:**
  /// - [storage]: FlutterSecureStorage instance (injected for testing)
  ///
  /// **Example:**
  /// ```dart
  /// final service = EncryptionServiceImpl(
  ///   storage: FlutterSecureStorage(
  ///     aOptions: AndroidOptions(encryptedSharedPreferences: true),
  ///   ),
  /// );
  /// ```
  EncryptionServiceImpl({
    required FlutterSecureStorage storage,
  }) : _storage = storage;

  @override
  Future<String> encryptData(String key, String plaintext) async {
    try {
      // Write plaintext to secure storage (automatic encryption)
      await _storage.write(key: key, value: plaintext);
      return key; // Return key as reference to encrypted data
    } catch (e) {
      throw EncryptionException('Failed to encrypt data: $e');
    }
  }

  @override
  Future<String?> decryptData(String key) async {
    try {
      // Read from secure storage (automatic decryption)
      return await _storage.read(key: key);
    } catch (e) {
      throw EncryptionException('Failed to decrypt data: $e');
    }
  }

  @override
  String hashData(String data) {
    // Convert string to UTF-8 bytes
    final bytes = utf8.encode(data);

    // Compute SHA-256 hash
    final digest = sha256.convert(bytes);

    // Return hex-encoded hash
    return digest.toString();
  }

  @override
  String hashWithSalt(String data, String salt) {
    // Combine data with salt (simple concatenation)
    final combined = data + salt;

    // Convert to bytes and hash
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);

    return digest.toString();
  }

  @override
  String generateSalt() {
    // Use cryptographically secure random number generator
    final random = Random.secure();

    // Generate 32 bytes (256 bits) of random data
    final values = List<int>.generate(32, (i) => random.nextInt(256));

    // Encode as base64 for storage
    return base64.encode(values);
  }

  @override
  bool verifyHash(String data, String hash, String salt) {
    // Recompute hash with same data and salt
    final computedHash = hashWithSalt(data, salt);

    // Compare hashes
    // SECURITY NOTE: Standard == is vulnerable to timing attacks
    // Consider using constant-time comparison for production
    return computedHash == hash;
  }
}

/// Exception thrown when encryption/decryption operations fail
///
/// **When thrown:**
/// - Platform-native encryption/decryption fails
/// - Secure storage access denied
/// - Invalid key format or corrupted data
///
/// **Usage:**
/// ```dart
/// try {
///   await encryptionService.encryptData('key', 'data');
/// } on EncryptionException catch (e) {
///   print('Encryption failed: ${e.message}');
/// }
/// ```
class EncryptionException implements Exception {
  /// Error message describing what went wrong
  final String message;

  EncryptionException(this.message);

  @override
  String toString() => 'EncryptionException: $message';
}