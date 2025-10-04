part of '../app_database.dart';

/// WHAT: User table schema for storing authenticated user data
///
/// WHY: Stores user profiles, authentication tokens, and role information to enable
/// offline-first authentication and user session management. Single source of truth
/// for user data in the local database.
///
/// TABLE SCHEMA:
/// ```sql
/// CREATE TABLE users (
///   id TEXT PRIMARY KEY,                -- Server-generated UUID
///   email TEXT NOT NULL,                -- User's email (unique on server)
///   firstName TEXT NOT NULL,
///   lastName TEXT NOT NULL,
///   phone TEXT NOT NULL,                -- Nigerian phone format
///   role TEXT NOT NULL,                 -- 'customer' | 'driver'
///   isVerified INTEGER NOT NULL DEFAULT 0,
///   accessToken TEXT,                   -- JWT access token (nullable)
///   refreshToken TEXT,                  -- JWT refresh token (nullable)
///   tokenExpiry DATETIME,               -- Token expiration timestamp
///   createdAt DATETIME NOT NULL,
///   updatedAt DATETIME NOT NULL,
///   lastSyncedAt DATETIME               -- Last sync with backend
/// );
/// ```
///
/// RELATIONSHIPS:
/// - 1:N with orders (one user can have many orders)
/// - 1:1 with drivers (one user can be one driver, via drivers.userId UNIQUE constraint)
///
/// INDEXES:
/// - PRIMARY KEY on id
/// - Backend has unique constraint on email (enforced server-side)
///
/// USAGE:
/// ```dart
/// // Create user record after login
/// final user = UserTableCompanion.insert(
///   id: 'uuid-from-server',
///   email: 'user@example.com',
///   firstName: 'John',
///   lastName: 'Doe',
///   phone: '+2348012345678',
///   role: 'customer',
///   isVerified: const Value(true),
///   accessToken: Value('jwt-token'),
///   refreshToken: Value('refresh-token'),
///   tokenExpiry: Value(DateTime.now().add(Duration(hours: 24))),
///   createdAt: DateTime.now(),
///   updatedAt: DateTime.now(),
/// );
/// await database.userDao.upsertUser(user);
///
/// // Query current user
/// final currentUser = await database.userDao.getCurrentUser();
/// ```
///
/// DATA LIFECYCLE:
/// - Created: On successful login/registration
/// - Updated: On token refresh, profile updates
/// - Deleted: On logout or account deletion
/// - Synced: Tokens updated on refresh, profile synced periodically
///
/// IMPROVEMENT OPPORTUNITIES:
/// - [HIGH] Encrypt accessToken and refreshToken fields (sensitive data)
/// - [MEDIUM] Add index on email for faster lookups during login
/// - [LOW] Add lastLoginAt timestamp to track user activity
/// - [MEDIUM] Consider adding profileImageUrl field for avatars
/// - [LOW] Add metadata field (JSON) for extensibility without schema changes
@DataClassName('UserTableData')
class UserTable extends Table {
  @override
  String get tableName => 'users';

  /// Unique user ID from backend
  TextColumn get id => text()();

  /// User's email address
  TextColumn get email => text()();

  /// User's first name
  TextColumn get firstName => text()();

  /// User's last name
  TextColumn get lastName => text()();

  /// User's phone number (Nigerian format)
  TextColumn get phone => text()();

  /// User role: 'customer' or 'driver'
  TextColumn get role => text()();

  /// User verification status
  BoolColumn get isVerified => boolean().withDefault(const Constant(false))();

  /// Access token for API authentication
  TextColumn get accessToken => text().nullable()();

  /// Refresh token for token renewal
  TextColumn get refreshToken => text().nullable()();

  /// Token expiration timestamp
  DateTimeColumn get tokenExpiry => dateTime().nullable()();

  /// Account creation timestamp
  DateTimeColumn get createdAt => dateTime()();

  /// Last update timestamp
  DateTimeColumn get updatedAt => dateTime()();

  /// Last sync with backend timestamp
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
