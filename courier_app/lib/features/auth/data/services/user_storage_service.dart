import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../domain/entities/user.dart';
import '../../domain/entities/user_role.dart';
import 'package:delivery_app/shared/models/user_model.dart';

/// [UserStorageService] - Secure persistent storage for user data and preferences
///
/// **What it does:**
/// - Stores complete user profile in encrypted secure storage
/// - Caches user role separately for quick access (no JSON parsing)
/// - Tracks last login timestamp for session management
/// - Manages "remember me" preference
/// - Validates session expiration (30-day default)
/// - Provides complete storage wipe on logout
///
/// **Why it exists:**
/// - User data must persist across app restarts
/// - Standard SharedPreferences is not secure for sensitive data
/// - FlutterSecureStorage provides platform-encrypted storage
/// - Separates storage concerns from repository logic
/// - Enables offline access to user profile
///
/// **Architecture:**
/// ```
/// AuthRepository
///       ↓
/// UserStorageService ← YOU ARE HERE
///       ↓
/// FlutterSecureStorage
///       ↓
/// Platform Keychain
/// ├─ iOS: Keychain Services
/// └─ Android: EncryptedSharedPreferences
/// ```
///
/// **Storage Keys:**
/// ```
/// cached_user          → Full user JSON
/// user_role            → Quick role lookup (customer/driver/admin)
/// last_login           → ISO8601 timestamp
/// remember_me          → "true"/"false" string
/// ```
///
/// **Data Flow:**
/// ```
/// Login
///   ↓
/// saveUser(user)
///   ↓
/// ├─ Serialize to JSON
/// ├─ Encrypt via platform
/// └─ Store in keychain
///
/// App Launch
///   ↓
/// getCachedUser()
///   ↓
/// ├─ Read from keychain
/// ├─ Decrypt via platform
/// ├─ Parse JSON
/// └─ Return User entity
/// ```
///
/// **Usage Example:**
/// ```dart
/// final userStorage = UserStorageService(
///   secureStorage: FlutterSecureStorage(),
/// );
///
/// // Save user after login
/// final user = User(id: '123', email: 'user@example.com');
/// await userStorage.saveUser(user);
///
/// // Retrieve on app launch
/// final cachedUser = await userStorage.getCachedUser();
/// if (cachedUser != null) {
///   // Check session validity
///   if (await userStorage.isSessionExpired()) {
///     await userStorage.clearUserData();
///     navigateToLogin();
///   }
/// }
///
/// // Quick role check (no JSON parsing)
/// final role = await userStorage.getCachedUserRole();
/// if (role == UserRoleType.driver) {
///   showDriverDashboard();
/// }
/// ```
///
/// **IMPROVEMENTS:**
/// - [High Priority] Return Either<Failure, T> instead of throwing exceptions
/// - Current exception handling forces try-catch everywhere
/// - [Medium Priority] Add data migration support for schema changes
/// - User model may evolve, need versioning strategy
/// - [Medium Priority] Implement automatic session extension on activity
/// - Currently fixed 30-day expiration regardless of usage
/// - [Low Priority] Add storage encryption verification on app start
/// - Detect if secure storage is compromised
/// - [Low Priority] Add backup/restore functionality for user data
class UserStorageService {
  /// Platform-encrypted secure storage instance
  ///
  /// **Why:**
  /// - iOS: Stores in Keychain with encryption
  /// - Android: Uses EncryptedSharedPreferences
  final FlutterSecureStorage _secureStorage;

  /// Storage key for complete user JSON
  static const String _userKey = 'cached_user';

  /// Storage key for quick role access
  static const String _userRoleKey = 'user_role';

  /// Storage key for login timestamp
  static const String _lastLoginKey = 'last_login';

  /// Storage key for remember me preference
  static const String _rememberMeKey = 'remember_me';

  UserStorageService({
    required FlutterSecureStorage secureStorage,
  }) : _secureStorage = secureStorage;

  /// Saves complete user profile to encrypted storage with metadata
  ///
  /// **What it does:**
  /// 1. Converts User entity to UserModel (data layer model)
  /// 2. Serializes UserModel to JSON string
  /// 3. Stores JSON in secure storage
  /// 4. Stores role separately for quick access
  /// 5. Records current timestamp as last login
  ///
  /// **Why convert to UserModel:**
  /// - Domain entities may lack serialization logic
  /// - UserModel has toJson/fromJson methods
  /// - Separation between domain and data representations
  ///
  /// **Flow Diagram:**
  /// ```
  /// saveUser(user)
  ///       ↓
  /// UserModel.fromEntity(user)
  ///       ↓
  /// JSON.encode(userModel)
  ///       ↓
  /// ├─ Store full JSON → 'cached_user'
  /// ├─ Store role string → 'user_role'
  /// └─ Store timestamp → 'last_login'
  /// ```
  ///
  /// **Throws:**
  /// - Exception: If storage write fails or serialization fails
  ///
  /// **Edge Cases:**
  /// - Storage full → Throws exception
  /// - Invalid user data → JSON encoding fails
  /// - Platform keychain locked → Storage write fails
  ///
  /// **Example:**
  /// ```dart
  /// try {
  ///   final user = User(
  ///     id: '123',
  ///     email: 'user@example.com',
  ///     role: UserRole(type: UserRoleType.driver),
  ///   );
  ///   await userStorage.saveUser(user);
  ///   print('User saved successfully');
  /// } catch (e) {
  ///   print('Failed to save user: $e');
  /// }
  /// ```
  ///
  /// **IMPROVEMENT:**
  /// - [High Priority] Return Either<Failure, Unit> instead of throwing
  /// - [Medium Priority] Add storage size limit check before write
  /// - Prevent storage exhaustion
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

  /// Retrieves cached user profile from encrypted storage
  ///
  /// **What it does:**
  /// 1. Reads user JSON string from secure storage
  /// 2. Validates JSON exists and is non-empty
  /// 3. Deserializes JSON to UserModel
  /// 4. Returns User entity (UserModel extends User)
  ///
  /// **Why return nullable:**
  /// - User may not be logged in (no cached data)
  /// - Storage may be corrupted (parsing fails)
  /// - Allows graceful handling of missing data
  ///
  /// **Flow Diagram:**
  /// ```
  /// getCachedUser()
  ///       ↓
  /// Read 'cached_user' key
  ///       ↓
  ///   JSON exists?
  ///    ↙       ↘
  ///  NO        YES
  ///   ↓         ↓
  /// null    JSON.decode()
  ///              ↓
  ///       UserModel.fromJson()
  ///              ↓
  ///         Return User
  /// ```
  ///
  /// **Returns:**
  /// - User: If cached user exists and is valid
  /// - null: If no cached user or parsing fails
  ///
  /// **Edge Cases:**
  /// - No cached user → Returns null (not logged in)
  /// - Empty JSON string → Returns null
  /// - Corrupted JSON → Returns null (catches exception)
  /// - Model schema mismatch → Returns null (fromJson fails)
  ///
  /// **Example:**
  /// ```dart
  /// final cachedUser = await userStorage.getCachedUser();
  /// if (cachedUser != null) {
  ///   print('Welcome back, ${cachedUser.firstName}!');
  ///   navigateToHome();
  /// } else {
  ///   print('Please log in');
  ///   navigateToLogin();
  /// }
  /// ```
  ///
  /// **IMPROVEMENT:**
  /// - [Medium Priority] Add JSON schema validation before parsing
  /// - Detect and migrate old data formats
  /// - [Low Priority] Log parsing errors for debugging
  /// - Currently silent failure on corruption
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

  /// Validates if user session has exceeded maximum age
  ///
  /// **What it does:**
  /// 1. Retrieves last login timestamp from storage
  /// 2. Compares with current time
  /// 3. Returns true if duration exceeds maxSessionAge
  /// 4. Defaults to 30-day session lifetime
  ///
  /// **Why session expiration:**
  /// - Security: Limits validity of stolen credentials
  /// - Compliance: Many regulations require session timeouts
  /// - UX: Ensures user data stays fresh
  ///
  /// **Flow Diagram:**
  /// ```
  /// isSessionExpired(maxAge)
  ///       ↓
  /// getLastLoginTime()
  ///       ↓
  ///   Login time exists?
  ///    ↙           ↘
  ///  NO            YES
  ///   ↓             ↓
  /// true (expired)  Calculate age
  ///                 ↓
  ///            age > maxAge?
  ///             ↙        ↘
  ///           YES        NO
  ///            ↓          ↓
  ///          true       false
  /// ```
  ///
  /// **Returns:**
  /// - true: Session expired or no login time found
  /// - false: Session still valid
  ///
  /// **Edge Cases:**
  /// - No last login timestamp → Returns true (expired)
  /// - Exception reading storage → Returns true (safe default)
  /// - Clock changed by user → May cause false expiration
  ///
  /// **Example:**
  /// ```dart
  /// // Check with default 30 days
  /// if (await userStorage.isSessionExpired()) {
  ///   await userStorage.clearUserData();
  ///   showMessage('Session expired, please log in again');
  ///   navigateToLogin();
  /// }
  ///
  /// // Check with custom duration
  /// if (await userStorage.isSessionExpired(
  ///   maxSessionAge: Duration(days: 7),
  /// )) {
  ///   requireReauthentication();
  /// }
  /// ```
  ///
  /// **IMPROVEMENT:**
  /// - [High Priority] Implement sliding expiration (extend on activity)
  /// - Currently absolute expiration regardless of app usage
  /// - [Medium Priority] Add server-side session validation
  /// - Local check can be bypassed by changing device clock
  /// - [Low Priority] Make maxSessionAge configurable per user role
  /// - Drivers might need longer sessions than customers
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
