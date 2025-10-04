part of '../app_database.dart';

/// WHAT: Data Access Object (DAO) for User table operations
///
/// WHY: Encapsulates all database operations for users, providing a clean API for
/// user authentication, profile management, and token handling. Abstracts SQL queries
/// and database logic from business layer (repositories and use cases).
///
/// RESPONSIBILITIES:
/// - User CRUD operations (get, insert/update, delete)
/// - Authentication token management (store, update, clear)
/// - Current user session management
/// - Real-time user data streaming via watch methods
///
/// QUERY PATTERNS:
/// - getCurrentUser(): Returns first user (single-user app assumption)
/// - getUserById(): Direct lookup by primary key
/// - upsertUser(): Insert or update on conflict (idempotent operation)
/// - watchCurrentUser(): Reactive stream for UI updates
///
/// USAGE:
/// ```dart
/// // Login - store user and tokens
/// final user = UserTableCompanion.insert(
///   id: loginResponse.userId,
///   email: loginResponse.email,
///   firstName: loginResponse.firstName,
///   lastName: loginResponse.lastName,
///   phone: loginResponse.phone,
///   role: loginResponse.role,
///   accessToken: Value(loginResponse.accessToken),
///   refreshToken: Value(loginResponse.refreshToken),
///   tokenExpiry: Value(loginResponse.tokenExpiry),
///   createdAt: DateTime.now(),
///   updatedAt: DateTime.now(),
/// );
/// await database.userDao.upsertUser(user);
///
/// // Token refresh
/// await database.userDao.updateTokens(
///   userId: currentUser.id,
///   accessToken: newToken,
///   refreshToken: newRefreshToken,
///   tokenExpiry: expiryDate,
/// );
///
/// // Logout - clear tokens but keep user profile
/// await database.userDao.clearTokens(currentUser.id);
///
/// // Full logout - delete user
/// await database.userDao.deleteUser(currentUser.id);
///
/// // Watch user for reactive UI
/// database.userDao.watchCurrentUser().listen((user) {
///   // Update UI when user changes
/// });
/// ```
///
/// IMPROVEMENT OPPORTUNITIES:
/// - [MEDIUM] Add getUserByEmail() for email-based lookups
/// - [LOW] Add updateProfile() method for partial profile updates
/// - [HIGH] Add token expiry check method (isTokenExpired())
/// - [LOW] Add lastLoginAt tracking when updating tokens
/// - [MEDIUM] Consider adding getRecentUsers() for multi-account support
@DriftAccessor(tables: [UserTable])
class UserDao extends DatabaseAccessor<AppDatabase> with _$UserDaoMixin {
  UserDao(super.db);

  /// Get current logged-in user
  Future<UserTableData?> getCurrentUser() async =>
      (select(userTable)..limit(1)).getSingleOrNull();

  /// Get user by ID
  Future<UserTableData?> getUserById(String id) async =>
      (select(userTable)..where((u) => u.id.equals(id))).getSingleOrNull();

  /// Insert or update user
  Future<void> upsertUser(UserTableData user) async {
    await into(userTable).insertOnConflictUpdate(user);
  }

  /// Update user tokens
  Future<void> updateTokens({
    required String userId,
    required String accessToken,
    required String refreshToken,
    required DateTime tokenExpiry,
  }) async {
    await (update(userTable)..where((u) => u.id.equals(userId))).write(
      UserTableCompanion(
        accessToken: Value(accessToken),
        refreshToken: Value(refreshToken),
        tokenExpiry: Value(tokenExpiry),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Clear user tokens (logout)
  Future<void> clearTokens(String userId) async {
    await (update(userTable)..where((u) => u.id.equals(userId))).write(
      const UserTableCompanion(
        accessToken: Value(null),
        refreshToken: Value(null),
        tokenExpiry: Value(null),
      ),
    );
  }

  /// Delete user
  Future<int> deleteUser(String userId) async =>
      (delete(userTable)..where((u) => u.id.equals(userId))).go();

  /// Delete all users
  Future<int> deleteAllUsers() async => delete(userTable).go();

  /// Mark user as synced
  Future<void> markAsSynced(String userId) async {
    await (update(userTable)..where((u) => u.id.equals(userId))).write(
      UserTableCompanion(
        lastSyncedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Watch current user for realtime updates
  Stream<UserTableData?> watchCurrentUser() =>
      (select(userTable)..limit(1)).watchSingleOrNull();
}
