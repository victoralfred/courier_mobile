import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../domain/entities/user.dart';
import '../../domain/entities/user_role.dart';
import 'package:delivery_app/shared/models/user_model.dart';

/// Service for persisting user data securely
class UserStorageService {
  final FlutterSecureStorage _secureStorage;

  static const String _userKey = 'cached_user';
  static const String _userRoleKey = 'user_role';
  static const String _lastLoginKey = 'last_login';
  static const String _rememberMeKey = 'remember_me';

  UserStorageService({
    required FlutterSecureStorage secureStorage,
  }) : _secureStorage = secureStorage;

  /// Save user data to secure storage
  Future<void> saveUser(User user) async {
    try {
      // Convert user to UserModel for JSON serialization
      final userModel = UserModel.fromEntity(user);
      final userJson = jsonEncode(userModel.toJson());

      await _secureStorage.write(key: _userKey, value: userJson);

      // Save role separately for quick access
      await _secureStorage.write(
        key: _userRoleKey,
        value: user.role.type.name,
      );

      // Save last login timestamp
      await _secureStorage.write(
        key: _lastLoginKey,
        value: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      throw Exception('Failed to save user: $e');
    }
  }

  /// Get cached user from secure storage
  Future<User?> getCachedUser() async {
    try {
      final userJson = await _secureStorage.read(key: _userKey);

      if (userJson == null || userJson.isEmpty) {
        return null;
      }

      final userMap = jsonDecode(userJson) as Map<String, dynamic>;
      return UserModel.fromJson(userMap);
    } catch (e) {
      // If there's an error reading or parsing, return null
      return null;
    }
  }

  /// Get user role quickly without parsing entire user object
  Future<UserRoleType?> getCachedUserRole() async {
    try {
      final roleString = await _secureStorage.read(key: _userRoleKey);

      if (roleString == null || roleString.isEmpty) {
        return null;
      }

      return UserRoleType.values.firstWhere(
        (role) => role.name == roleString,
        orElse: () => UserRoleType.customer,
      );
    } catch (e) {
      return null;
    }
  }

  /// Clear all cached user data
  Future<void> clearUserData() async {
    try {
      await _secureStorage.delete(key: _userKey);
      await _secureStorage.delete(key: _userRoleKey);
      await _secureStorage.delete(key: _lastLoginKey);
      // Keep remember me preference
    } catch (e) {
      throw Exception('Failed to clear user data: $e');
    }
  }

  /// Check if user data exists
  Future<bool> hasUserData() async {
    try {
      final userJson = await _secureStorage.read(key: _userKey);
      return userJson != null && userJson.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get last login time
  Future<DateTime?> getLastLoginTime() async {
    try {
      final timeString = await _secureStorage.read(key: _lastLoginKey);

      if (timeString == null || timeString.isEmpty) {
        return null;
      }

      return DateTime.parse(timeString);
    } catch (e) {
      return null;
    }
  }

  /// Check if session is expired (e.g., after 30 days)
  Future<bool> isSessionExpired({
    Duration maxSessionAge = const Duration(days: 30),
  }) async {
    try {
      final lastLogin = await getLastLoginTime();

      if (lastLogin == null) {
        return true;
      }

      final now = DateTime.now();
      return now.difference(lastLogin) > maxSessionAge;
    } catch (e) {
      return true;
    }
  }

  /// Set remember me preference
  Future<void> setRememberMe(bool value) async {
    try {
      await _secureStorage.write(
        key: _rememberMeKey,
        value: value.toString(),
      );
    } catch (e) {
      throw Exception('Failed to save remember me preference: $e');
    }
  }

  /// Get remember me preference
  Future<bool> getRememberMe() async {
    try {
      final value = await _secureStorage.read(key: _rememberMeKey);
      return value == 'true';
    } catch (e) {
      return false;
    }
  }

  /// Clear all storage (for logout or app reset)
  Future<void> clearAll() async {
    try {
      await _secureStorage.deleteAll();
    } catch (e) {
      throw Exception('Failed to clear all storage: $e');
    }
  }
}
