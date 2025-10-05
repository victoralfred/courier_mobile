import 'dart:convert';
import 'package:delivery_app/core/error/exceptions.dart';
import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:delivery_app/shared/models/user_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [AuthLocalDataSource] - Abstract interface for authentication local data operations
///
/// **Contract Definition:**
/// Defines operations for local caching and secure storage of authentication data.
/// Implementations use platform-specific storage (SharedPreferences, FlutterSecureStorage).
abstract class AuthLocalDataSource {
  /// Caches the current user data
  Future<void> cacheUser(UserModel user);

  /// Gets the cached user data
  Future<UserModel?> getCachedUser();

  /// Clears the cached user data
  Future<void> clearCachedUser();

  /// Checks if biometric authentication is enabled
  Future<bool> isBiometricEnabled();

  /// Enables biometric authentication
  Future<void> enableBiometric(String credentials);

  /// Disables biometric authentication
  Future<void> disableBiometric();

  /// Gets biometric credentials
  Future<String?> getBiometricCredentials();

  /// Saves the user's role
  Future<void> saveUserRole(String role);

  /// Gets the user's role
  Future<String?> getUserRole();

  /// Checks if this is the first app launch
  Future<bool> isFirstLaunch();

  /// Sets the first launch flag
  Future<void> setFirstLaunch(bool value);

  /// Gets the last login timestamp
  Future<DateTime?> getLastLoginTime();

  /// Sets the last login timestamp
  Future<void> setLastLoginTime(DateTime time);
}

/// [AuthLocalDataSourceImpl] - Local caching and secure storage for authentication data
///
/// **What it does:**
/// - Caches user data in SharedPreferences for fast access
/// - Stores sensitive biometric credentials in FlutterSecureStorage
/// - Manages biometric authentication preferences
/// - Tracks first app launch for onboarding flow
/// - Records last login timestamp for session management
/// - Stores user role for quick role-based access control
///
/// **Why it exists:**
/// - Provides offline access to user data (no network required)
/// - Enables fast app launch (cached user available immediately)
/// - Secures sensitive biometric credentials with encryption
/// - Separates storage concerns from business logic
/// - Implements two-tier storage strategy (fast cache + secure vault)
/// - Enables testing with mock storage implementations
///
/// **Architecture:**
/// ```
/// AuthRepository
///       ↓
/// AuthLocalDataSource ← YOU ARE HERE
///       ↓
/// ├─ SharedPreferences (fast, unencrypted cache)
/// │    ├─ cached_user (JSON string)
/// │    ├─ user_role (string)
/// │    ├─ biometric_enabled (boolean)
/// │    ├─ first_launch (boolean)
/// │    └─ last_login_time (timestamp)
/// └─ FlutterSecureStorage (encrypted vault)
///      └─ biometric_credentials (encrypted string)
/// ```
///
/// **Storage Strategy:**
/// ```
/// Non-Sensitive Data → SharedPreferences
/// ├─ User profile (cached_user)
/// ├─ User role (quick access)
/// ├─ Preferences (biometric_enabled, first_launch)
/// └─ Metadata (last_login_time)
///
/// Sensitive Data → FlutterSecureStorage
/// └─ Biometric credentials (email:password)
///      ├─ iOS: Keychain with encryption
///      └─ Android: EncryptedSharedPreferences
/// ```
///
/// **Platform Security:**
/// ```
/// iOS:
/// - FlutterSecureStorage → Keychain Services
/// - Accessibility: first_unlock_this_device
/// - Account: CourierAppAuth
/// - Protected by device passcode/biometrics
///
/// Android:
/// - FlutterSecureStorage → EncryptedSharedPreferences
/// - AES-256 encryption
/// - resetOnError: true (handles encryption key rotation)
/// ```
///
/// **Data Flow:**
/// ```
/// Login Success
///       ↓
/// cacheUser(userModel)
///       ↓
/// ├─ Serialize to JSON
/// ├─ Store in SharedPreferences
/// └─ Store role separately
///
/// App Launch
///       ↓
/// getCachedUser()
///       ↓
/// ├─ Read from SharedPreferences
/// ├─ Deserialize JSON
/// └─ Return UserModel (or null)
/// ```
///
/// **Usage Example:**
/// ```dart
/// final localDataSource = AuthLocalDataSourceImpl(
///   secureStorage: FlutterSecureStorage(),
///   preferences: await SharedPreferences.getInstance(),
/// );
///
/// // Cache user after login
/// final user = UserModel(...);
/// await localDataSource.cacheUser(user);
///
/// // Quick role check (no JSON parsing)
/// final role = await localDataSource.getUserRole();
/// if (role == 'driver') {
///   showDriverUI();
/// }
///
/// // Get cached user
/// final cachedUser = await localDataSource.getCachedUser();
///
/// // Enable biometric login
/// await localDataSource.enableBiometric('user@example.com:password123');
///
/// // Check if first launch
/// if (await localDataSource.isFirstLaunch()) {
///   showOnboarding();
///   await localDataSource.setFirstLaunch(false);
/// }
/// ```
///
/// **Biometric Credentials Storage:**
/// - Format: "email:password" (colon-separated)
/// - Encrypted by platform (Keychain/EncryptedSharedPreferences)
/// - Only accessible after biometric authentication
/// - Deleted when biometric is disabled
///
/// **IMPROVEMENTS:**
/// - [High Priority] Change biometric credentials format to JSON
///   - Current "email:password" format is fragile (what if password contains ':')
///   - Use JSON: {"email": "...", "password": "..."}
/// - [High Priority] Return Either<Failure, T> instead of throwing exceptions
///   - Current exception handling forces try-catch everywhere
/// - [Medium Priority] Add data encryption for cached_user in SharedPreferences
///   - Currently unencrypted (less sensitive but still user data)
/// - [Medium Priority] Implement cache TTL (time-to-live)
///   - Automatically expire cached user after N days
/// - [Low Priority] Add storage size monitoring
///   - Alert if storage quota exceeded
/// - [Low Priority] Implement cache versioning for migration
///   - Handle schema changes in cached data
@LazySingleton(as: AuthLocalDataSource)
class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _preferences;

  // Secure storage keys
  static const String _biometricCredentialsKey = 'biometric_credentials';

  // Shared preferences keys
  static const String _cachedUserKey = 'cached_user';
  static const String _userRoleKey = 'user_role';
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _firstLaunchKey = 'first_launch';
  static const String _lastLoginTimeKey = 'last_login_time';

  AuthLocalDataSourceImpl({
    required FlutterSecureStorage secureStorage,
    required SharedPreferences preferences,
  })  : _secureStorage = secureStorage,
        _preferences = preferences;

  // Secure storage options with additional security
  static const _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
    resetOnError: true,
  );

  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
    accountName: 'CourierAppAuth',
  );

  @override
  Future<void> cacheUser(UserModel user) async {
    try {
      final jsonString = json.encode(user.toJson());
      await _preferences.setString(_cachedUserKey, jsonString);
    } catch (e) {
      throw CacheException(
        message: AppStrings.format(
          AppStrings.errorCacheFailed,
          {'operation': 'cache user', 'error': e.toString()},
        ),
      );
    }
  }

  @override
  Future<UserModel?> getCachedUser() async {
    try {
      final jsonString = _preferences.getString(_cachedUserKey);
      if (jsonString != null) {
        final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
        return UserModel.fromJson(jsonMap);
      }
      return null;
    } catch (e) {
      throw CacheException(
        message: AppStrings.format(
          AppStrings.errorCacheFailed,
          {'operation': 'get cached user', 'error': e.toString()},
        ),
      );
    }
  }

  @override
  Future<void> clearCachedUser() async {
    try {
      await _preferences.remove(_cachedUserKey);
    } catch (e) {
      throw CacheException(
        message: AppStrings.format(
          AppStrings.errorCacheFailed,
          {'operation': 'clear cached user', 'error': e.toString()},
        ),
      );
    }
  }

  @override
  Future<bool> isBiometricEnabled() async {
    try {
      return _preferences.getBool(_biometricEnabledKey) ?? false;
    } catch (e) {
      throw CacheException(
        message: AppStrings.format(
          AppStrings.errorCacheFailed,
          {'operation': 'check biometric status', 'error': e.toString()},
        ),
      );
    }
  }

  @override
  Future<void> enableBiometric(String credentials) async {
    try {
      // Store encrypted credentials securely
      await _secureStorage.write(
        key: _biometricCredentialsKey,
        value: credentials,
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );

      await _preferences.setBool(_biometricEnabledKey, true);
    } catch (e) {
      throw CacheException(
        message: AppStrings.format(
          AppStrings.errorCacheFailed,
          {'operation': 'enable biometric', 'error': e.toString()},
        ),
      );
    }
  }

  @override
  Future<void> disableBiometric() async {
    try {
      await _secureStorage.delete(
        key: _biometricCredentialsKey,
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );

      await _preferences.setBool(_biometricEnabledKey, false);
    } catch (e) {
      throw CacheException(
        message: AppStrings.format(
          AppStrings.errorCacheFailed,
          {'operation': 'disable biometric', 'error': e.toString()},
        ),
      );
    }
  }

  @override
  Future<String?> getBiometricCredentials() async {
    try {
      return await _secureStorage.read(
        key: _biometricCredentialsKey,
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );
    } catch (e) {
      throw CacheException(
        message: AppStrings.format(
          AppStrings.errorCacheFailed,
          {'operation': 'get biometric credentials', 'error': e.toString()},
        ),
      );
    }
  }

  @override
  Future<void> saveUserRole(String role) async {
    try {
      await _preferences.setString(_userRoleKey, role);
    } catch (e) {
      throw CacheException(
        message: AppStrings.format(
          AppStrings.errorCacheFailed,
          {'operation': 'save user role', 'error': e.toString()},
        ),
      );
    }
  }

  @override
  Future<String?> getUserRole() async {
    try {
      return _preferences.getString(_userRoleKey);
    } catch (e) {
      throw CacheException(
        message: AppStrings.format(
          AppStrings.errorCacheFailed,
          {'operation': 'get user role', 'error': e.toString()},
        ),
      );
    }
  }

  @override
  Future<bool> isFirstLaunch() async {
    try {
      return _preferences.getBool(_firstLaunchKey) ?? true;
    } catch (e) {
      throw CacheException(
        message: AppStrings.format(
          AppStrings.errorCacheFailed,
          {'operation': 'check first launch', 'error': e.toString()},
        ),
      );
    }
  }

  @override
  Future<void> setFirstLaunch(bool value) async {
    try {
      await _preferences.setBool(_firstLaunchKey, value);
    } catch (e) {
      throw CacheException(
        message: AppStrings.format(
          AppStrings.errorCacheFailed,
          {'operation': 'set first launch', 'error': e.toString()},
        ),
      );
    }
  }

  @override
  Future<DateTime?> getLastLoginTime() async {
    try {
      final timestamp = _preferences.getInt(_lastLoginTimeKey);
      if (timestamp != null) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      return null;
    } catch (e) {
      throw CacheException(
        message: AppStrings.format(
          AppStrings.errorCacheFailed,
          {'operation': 'get last login time', 'error': e.toString()},
        ),
      );
    }
  }

  @override
  Future<void> setLastLoginTime(DateTime time) async {
    try {
      await _preferences.setInt(
        _lastLoginTimeKey,
        time.millisecondsSinceEpoch,
      );
    } catch (e) {
      throw CacheException(
        message: AppStrings.format(
          AppStrings.errorCacheFailed,
          {'operation': 'set last login time', 'error': e.toString()},
        ),
      );
    }
  }
}
