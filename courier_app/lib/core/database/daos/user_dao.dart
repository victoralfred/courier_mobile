part of '../app_database.dart';

/// Data Access Object for User operations
///
/// Provides CRUD operations and queries for user data
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
