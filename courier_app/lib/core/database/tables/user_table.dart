part of '../app_database.dart';

/// User table for storing authenticated users
///
/// Stores user information including role (customer/driver)
/// and authentication tokens for offline access
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
