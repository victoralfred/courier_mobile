import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for encrypting and decrypting sensitive data
/// Uses flutter_secure_storage which provides platform-native encryption
/// Additional hashing utilities using SHA-256
abstract class EncryptionService {
  /// Encrypt plaintext data using secure storage
  Future<String> encryptData(String key, String plaintext);

  /// Decrypt encrypted data from secure storage
  Future<String?> decryptData(String key);

  /// Hash data using SHA-256
  String hashData(String data);

  /// Hash data with salt
  String hashWithSalt(String data, String salt);

  /// Generate secure random salt
  String generateSalt();

  /// Verify hashed data
  bool verifyHash(String data, String hash, String salt);
}

/// Implementation of EncryptionService
/// Leverages flutter_secure_storage for encryption (uses Keychain on iOS, KeyStore on Android)
class EncryptionServiceImpl implements EncryptionService {
  final FlutterSecureStorage _storage;

  EncryptionServiceImpl({
    required FlutterSecureStorage storage,
  }) : _storage = storage;

  @override
  Future<String> encryptData(String key, String plaintext) async {
    try {
      await _storage.write(key: key, value: plaintext);
      return key; // Return key as reference
    } catch (e) {
      throw EncryptionException('Failed to encrypt data: $e');
    }
  }

  @override
  Future<String?> decryptData(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      throw EncryptionException('Failed to decrypt data: $e');
    }
  }

  @override
  String hashData(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  @override
  String hashWithSalt(String data, String salt) {
    final combined = data + salt;
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  @override
  String generateSalt() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64.encode(values);
  }

  @override
  bool verifyHash(String data, String hash, String salt) {
    final computedHash = hashWithSalt(data, salt);
    return computedHash == hash;
  }
}

/// Exception thrown when encryption/decryption fails
class EncryptionException implements Exception {
  final String message;

  EncryptionException(this.message);

  @override
  String toString() => 'EncryptionException: $message';
}