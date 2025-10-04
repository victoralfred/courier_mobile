import 'package:dartz/dartz.dart';
import 'package:delivery_app/core/error/failures.dart';
import 'package:delivery_app/core/domain/value_objects/coordinate.dart';
import 'package:delivery_app/features/drivers/domain/entities/driver.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/availability_status.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/driver_status.dart';

/// [DriverRepository] - Repository interface defining driver data operation contracts
///
/// **What it does:**
/// - Defines driver CRUD operations (create, read, update, delete)
/// - Provides driver lookup by ID and user ID
/// - Supports driver status management (pending, approved, rejected, suspended)
/// - Manages driver availability updates (offline, available, busy)
/// - Handles driver location tracking (update, clear)
/// - Updates driver ratings
/// - Returns Either<Failure, T> for error handling
/// - Abstracts data sources (remote API + local database)
/// - Provides real-time driver updates via streams
///
/// **Why it exists:**
/// - Separates domain logic from data layer (Clean Architecture)
/// - Enables dependency inversion (depend on interface, not implementation)
/// - Makes driver operations testable (mock repository in tests)
/// - Centralizes driver data contracts in one place
/// - Supports hybrid data strategy (remote + local sync)
/// - Enables offline-first driver management
///
/// **Clean Architecture Layers:**
/// ```
/// ┌─────────────────────────────────────────────────────────────┐
/// │ Presentation Layer (BLoC/Cubit)                             │
/// │ - DriverBloc, DriverProfileCubit                            │
/// │ - Manages UI state and user interactions                    │
/// └─────────────────────────────────────────────────────────────┘
///                           ↓ calls
/// ┌─────────────────────────────────────────────────────────────┐
/// │ Domain Layer (Use Cases)                                    │
/// │ - GetDriverUseCase, UpdateDriverStatusUseCase               │
/// │ - UpdateDriverAvailabilityUseCase, etc.                     │
/// │ - Contains business logic validation                        │
/// └─────────────────────────────────────────────────────────────┘
///                           ↓ depends on
/// ┌─────────────────────────────────────────────────────────────┐
/// │ Domain Layer (Repository Interface) ← YOU ARE HERE          │
/// │ - DriverRepository (abstract class)                         │
/// │ - Defines contracts for driver data operations              │
/// └─────────────────────────────────────────────────────────────┘
///                           ↑ implemented by
/// ┌─────────────────────────────────────────────────────────────┐
/// │ Data Layer (Repository Implementation)                      │
/// │ - DriverRepositoryImpl                                      │
/// │ - Coordinates remote and local data sources                 │
/// │ - Handles offline-first strategy                            │
/// └─────────────────────────────────────────────────────────────┘
///                           ↓ uses
/// ┌─────────────────────────────────────────────────────────────┐
/// │ Data Layer (Data Sources)                                   │
/// │ - DriverRemoteDataSource (REST API)                         │
/// │ - DriverLocalDataSource (Drift/SQLite)                      │
/// │ - WebSocket for real-time updates                           │
/// └─────────────────────────────────────────────────────────────┘
/// ```
///
/// **Data Flow (Fetch Driver from Backend):**
/// ```
/// User Action (e.g., Login)
///       ↓
/// DriverBloc → GetDriverUseCase
///       ↓
/// GetDriverUseCase → DriverRepository.fetchDriverFromBackend(userId)
///       ↓
/// DriverRepositoryImpl
///       ↓
///   ┌───┴───────────────────────────────┐
///   ↓ Remote                             ↓ Local
/// GET /drivers/by-user/{userId}    Check local DB
///   ↓                                    ↓
/// Receive Driver JSON              Find cached driver
///   ↓                                    ↓
/// Convert to Driver Entity         Return if exists
///   ↓
/// Save to Local DB ←──────────────────┘
///   ↓
/// Return Either<Failure, Driver>
///   ↓
/// GetDriverUseCase → DriverBloc
///   ↓
/// Emit DriverLoaded(driver) → UI
/// ```
///
/// **Offline-First Strategy:**
/// ```
/// Read Operations (getDriverById, getDriverByUserId):
///   1. Check local database FIRST (fast, offline-capable)
///   2. Return cached data immediately
///   3. Optionally sync in background
///
/// Write Operations (upsertDriver, updateStatus, updateAvailability):
///   1. Validate data
///   2. Try remote API call
///   3. If success: Save to local DB
///   4. If network failure: Queue for later sync, save locally
///   5. Return success/failure
///
/// Real-time Operations (watchDriverById, watchDriverByUserId):
///   1. Watch local database (reactive stream)
///   2. Listen to WebSocket for remote changes
///   3. Update local DB when remote changes detected
///   4. Stream automatically emits new data
/// ```
///
/// **Driver Onboarding Flow (upsertDriver):**
/// ```
/// Driver Fills Onboarding Form
///       ↓
/// Create Driver Entity
///       ↓
/// Validate (factory constructor)
///       ↓
/// DriverRepository.upsertDriver(driver)
///       ↓
/// POST /drivers {driverJson}
///       ↓
///   ┌───┴────┐
///   ↓        ↓
/// Success  Failure
///   ↓        ↓
/// Receive  Queue for
/// Driver   offline sync
///   ↓        ↓
/// Save to Local DB
///       ↓
/// Return Right(Driver)
///       ↓
/// Navigate to "Pending Approval" screen
/// ```
///
/// **Real-time Location Tracking Flow:**
/// ```
/// Driver Goes Online
///       ↓
/// GPS Service Started (every 15 seconds)
///       ↓
/// updateLocation(driverId, gpsCoords)
///       ↓
/// POST /drivers/{id}/location
///       ↓
/// Update Local DB
///       ↓
/// watchDriverById stream emits new location
///       ↓
/// Admin Dashboard Updates (WebSocket)
///       ↓
/// Order Assignment System sees new location
/// ```
///
/// **Error Handling Pattern:**
/// - Uses Either<Failure, T> from dartz package
/// - Left: Failure (NetworkFailure, ServerFailure, NotFoundFailure, etc.)
/// - Right: Success value (Driver, List<Driver>, bool, etc.)
/// - Forces explicit error handling in use cases and BLoCs
///
/// **Usage Example:**
/// ```dart
/// // In use case
/// class GetDriverByUserIdUseCase {
///   final DriverRepository repository;
///
///   Future<Either<Failure, Driver>> call(String userId) {
///     return repository.getDriverByUserId(userId);
///   }
/// }
///
/// // In BLoC
/// final result = await getDriverByUserIdUseCase(userId);
/// result.fold(
///   (failure) => emit(DriverError(failure.message)),
///   (driver) => emit(DriverLoaded(driver)),
/// );
///
/// // Real-time updates
/// repository.watchDriverByUserId(userId).listen((driver) {
///   if (driver != null) {
///     emit(DriverUpdated(driver));
///   }
/// });
/// ```
///
/// **IMPROVEMENT:**
/// - [High Priority] Add batch operations (update multiple drivers)
/// - [High Priority] Add driver search/filter (by status, rating, location radius)
/// - [Medium Priority] Add driver statistics (total deliveries, acceptance rate)
/// - [Medium Priority] Add driver document upload/management
/// - [Medium Priority] Add driver performance metrics
/// - [Low Priority] Add driver preferences management
/// - [Low Priority] Add driver availability schedule (recurring hours)
abstract class DriverRepository {
  /// Gets a driver by driver ID from local database
  ///
  /// **What it does:**
  /// - Fetches driver from local database (SQLite/Drift)
  /// - Returns cached driver data (no network call)
  /// - Fast lookup for driver profile display
  ///
  /// **Parameters:**
  /// - [id]: Driver ID (not user ID)
  ///
  /// **Returns:**
  /// - Right(Driver): Driver found in local database
  /// - Left(NotFoundFailure): Driver not found
  /// - Left(DatabaseFailure): Database error
  ///
  /// **Example:**
  /// ```dart
  /// final result = await repository.getDriverById('drv_123');
  /// result.fold(
  ///   (failure) => print('Driver not found: ${failure.message}'),
  ///   (driver) => print('Found driver: ${driver.fullName}'),
  /// );
  /// ```
  Future<Either<Failure, Driver>> getDriverById(String id);

  /// Gets a driver by user ID from local database
  ///
  /// **What it does:**
  /// - Fetches driver from local database using user ID
  /// - Returns cached driver data (no network call)
  /// - Enables user -> driver lookup
  ///
  /// **When to use:**
  /// - App startup (check if logged-in user is a driver)
  /// - Driver profile screen load
  /// - Quick local lookup (no network required)
  ///
  /// **Parameters:**
  /// - [userId]: User account ID (from authentication)
  ///
  /// **Returns:**
  /// - Right(Driver): Driver found in local database
  /// - Left(NotFoundFailure): No driver profile for this user
  /// - Left(DatabaseFailure): Database error
  ///
  /// **Example:**
  /// ```dart
  /// final userId = authRepository.getCurrentUserId();
  /// final result = await repository.getDriverByUserId(userId);
  /// result.fold(
  ///   (failure) => navigateToDriverOnboarding(),
  ///   (driver) => navigateToDriverDashboard(driver),
  /// );
  /// ```
  Future<Either<Failure, Driver>> getDriverByUserId(String userId);

  /// Fetches driver from backend API and syncs to local database
  ///
  /// **What it does:**
  /// - Fetches fresh driver data from backend API
  /// - Updates local database with latest data
  /// - Returns updated driver entity
  ///
  /// **When to use:**
  /// - User login (sync remote driver data)
  /// - Pull-to-refresh driver profile
  /// - Verify driver status after admin approval
  /// - Periodic background sync
  ///
  /// **Flow:**
  /// ```
  /// 1. GET /drivers/by-user/{userId} (with auth token)
  /// 2. Receive driver JSON from backend
  /// 3. Convert to Driver entity
  /// 4. Save to local database
  /// 5. Return Driver
  /// ```
  ///
  /// **Parameters:**
  /// - [userId]: User account ID
  ///
  /// **Returns:**
  /// - Right(Driver): Driver fetched and synced successfully
  /// - Left(NotFoundFailure): No driver profile exists (404)
  /// - Left(NetworkFailure): Network error
  /// - Left(ServerFailure): Backend error (500)
  /// - Left(AuthFailure): Unauthorized (401)
  ///
  /// **Example:**
  /// ```dart
  /// // Sync driver on app startup
  /// final result = await repository.fetchDriverFromBackend(userId);
  /// result.fold(
  ///   (failure) => print('Sync failed: ${failure.message}'),
  ///   (driver) => print('Synced driver: ${driver.fullName}'),
  /// );
  /// ```
  Future<Either<Failure, Driver>> fetchDriverFromBackend(String userId);

  /// Creates or updates a driver profile (upsert operation)
  ///
  /// **What it does:**
  /// - Creates new driver if doesn't exist
  /// - Updates existing driver if already exists
  /// - Sends to backend API (if online)
  /// - Saves to local database
  ///
  /// **When to use:**
  /// - Driver onboarding (create new profile)
  /// - Driver profile update (edit vehicle info, contact details)
  /// - Offline driver creation (sync later)
  ///
  /// **Flow:**
  /// ```
  /// 1. Validate driver entity
  /// 2. POST/PUT /drivers (with auth token)
  /// 3. Receive updated driver from backend
  /// 4. Save to local database
  /// 5. Return Driver
  /// ```
  ///
  /// **Parameters:**
  /// - [driver]: Driver entity to create/update
  ///
  /// **Returns:**
  /// - Right(Driver): Driver created/updated successfully
  /// - Left(ValidationFailure): Invalid driver data
  /// - Left(NetworkFailure): Network error (queued for offline sync)
  /// - Left(ServerFailure): Backend error
  ///
  /// **Example:**
  /// ```dart
  /// final newDriver = Driver(
  ///   id: uuid.v4(),
  ///   userId: currentUser.id,
  ///   firstName: 'Amaka',
  ///   lastName: 'Nwosu',
  ///   email: 'amaka@example.com',
  ///   phone: '+2348098765432',
  ///   licenseNumber: 'LAG-67890-XY',
  ///   vehicleInfo: vehicleInfo,
  ///   status: DriverStatus.pending,
  ///   availability: AvailabilityStatus.offline,
  ///   rating: 0.0,
  ///   totalRatings: 0,
  /// );
  ///
  /// final result = await repository.upsertDriver(newDriver);
  /// ```
  Future<Either<Failure, Driver>> upsertDriver(Driver driver);

  /// Updates driver verification status
  ///
  /// **What it does:**
  /// - Updates driver status (pending → approved/rejected/suspended)
  /// - Sends status update to backend (admin API)
  /// - Updates local database
  /// - Returns updated driver entity
  ///
  /// **When to use:**
  /// - Admin approval workflow
  /// - Driver application rejection
  /// - Driver account suspension
  /// - Status reactivation
  ///
  /// **Status Transitions:**
  /// - pending → approved (admin verifies driver)
  /// - pending → rejected (admin denies application)
  /// - approved → suspended (violation detected)
  /// - suspended → approved (suspension lifted)
  ///
  /// **Parameters:**
  /// - [driverId]: Driver ID to update
  /// - [status]: New status (pending, approved, rejected, suspended)
  ///
  /// **Returns:**
  /// - Right(Driver): Status updated successfully
  /// - Left(NotFoundFailure): Driver not found
  /// - Left(AuthFailure): Unauthorized (admin only)
  /// - Left(NetworkFailure): Network error
  ///
  /// **Example:**
  /// ```dart
  /// // Admin approves driver
  /// final result = await repository.updateStatus(
  ///   driverId: 'drv_123',
  ///   status: DriverStatus.approved,
  /// );
  /// ```
  Future<Either<Failure, Driver>> updateStatus({
    required String driverId,
    required DriverStatus status,
  });

  /// Updates driver availability for order assignment
  ///
  /// **What it does:**
  /// - Updates driver availability (offline, available, busy)
  /// - Sends to backend for real-time tracking
  /// - Updates local database
  /// - Returns updated driver entity
  ///
  /// **When to use:**
  /// - Driver goes online (offline → available)
  /// - Driver goes offline (available → offline)
  /// - Driver accepts order (available → busy)
  /// - Driver completes delivery (busy → available)
  ///
  /// **Availability States:**
  /// - offline: Not working, can't accept orders
  /// - available: Online and ready for orders
  /// - busy: Currently handling an order
  ///
  /// **Parameters:**
  /// - [driverId]: Driver ID to update
  /// - [availability]: New availability (offline, available, busy)
  ///
  /// **Returns:**
  /// - Right(Driver): Availability updated successfully
  /// - Left(NotFoundFailure): Driver not found
  /// - Left(ValidationFailure): Invalid transition (e.g., suspended driver trying to go online)
  /// - Left(NetworkFailure): Network error
  ///
  /// **Example:**
  /// ```dart
  /// // Driver goes online
  /// final result = await repository.updateAvailability(
  ///   driverId: driver.id,
  ///   availability: AvailabilityStatus.available,
  /// );
  /// ```
  Future<Either<Failure, Driver>> updateAvailability({
    required String driverId,
    required AvailabilityStatus availability,
  });

  /// Updates driver's current GPS location
  ///
  /// **What it does:**
  /// - Updates driver's current location coordinates
  /// - Sends to backend for real-time tracking
  /// - Updates local database
  /// - Sets lastLocationUpdate timestamp
  ///
  /// **When to use:**
  /// - Periodic location updates (every 10-30 seconds when online)
  /// - Driver movement tracking during delivery
  /// - Nearest driver calculation for order assignment
  ///
  /// **Parameters:**
  /// - [driverId]: Driver ID to update
  /// - [location]: GPS coordinates (latitude, longitude)
  ///
  /// **Returns:**
  /// - Right(Driver): Location updated successfully
  /// - Left(NotFoundFailure): Driver not found
  /// - Left(NetworkFailure): Network error (queued for later sync)
  ///
  /// **Example:**
  /// ```dart
  /// // Update location from GPS
  /// final result = await repository.updateLocation(
  ///   driverId: driver.id,
  ///   location: Coordinate(
  ///     latitude: 6.5244,
  ///     longitude: 3.3792,
  ///   ),
  /// );
  /// ```
  Future<Either<Failure, Driver>> updateLocation({
    required String driverId,
    required Coordinate location,
  });

  /// Clears driver's current location (when going offline)
  ///
  /// **What it does:**
  /// - Sets currentLocation to null
  /// - Clears lastLocationUpdate timestamp
  /// - Sends to backend to stop location tracking
  /// - Updates local database
  ///
  /// **When to use:**
  /// - Driver goes offline
  /// - Driver ends work shift
  /// - Privacy mode enabled
  ///
  /// **Parameters:**
  /// - [driverId]: Driver ID to clear location
  ///
  /// **Returns:**
  /// - Right(Driver): Location cleared successfully
  /// - Left(NotFoundFailure): Driver not found
  /// - Left(NetworkFailure): Network error
  ///
  /// **Example:**
  /// ```dart
  /// // Clear location when going offline
  /// await repository.clearLocation(driver.id);
  /// await repository.updateAvailability(
  ///   driverId: driver.id,
  ///   availability: AvailabilityStatus.offline,
  /// );
  /// ```
  Future<Either<Failure, Driver>> clearLocation(String driverId);

  /// Updates driver rating after delivery completion
  ///
  /// **What it does:**
  /// - Updates driver's average rating
  /// - Increments total ratings count
  /// - Sends to backend for permanent storage
  /// - Updates local database
  ///
  /// **When to use:**
  /// - Customer rates completed delivery
  /// - Rating recalculation (admin correction)
  ///
  /// **Calculation:**
  /// - New rating = (sum of all ratings) / totalRatings
  /// - Rating range: 0.0 - 5.0
  ///
  /// **Parameters:**
  /// - [driverId]: Driver ID to update
  /// - [rating]: New average rating (0.0 - 5.0)
  /// - [totalRatings]: Total number of ratings
  ///
  /// **Returns:**
  /// - Right(Driver): Rating updated successfully
  /// - Left(NotFoundFailure): Driver not found
  /// - Left(ValidationFailure): Invalid rating (< 0 or > 5)
  /// - Left(NetworkFailure): Network error
  ///
  /// **Example:**
  /// ```dart
  /// // Update rating after customer feedback
  /// final newRating = calculateNewRating(driver.rating, driver.totalRatings, 5.0);
  /// final result = await repository.updateRating(
  ///   driverId: driver.id,
  ///   rating: newRating,
  ///   totalRatings: driver.totalRatings + 1,
  /// );
  /// ```
  Future<Either<Failure, Driver>> updateRating({
    required String driverId,
    required double rating,
    required int totalRatings,
  });

  /// Gets all available drivers for order assignment
  ///
  /// **What it does:**
  /// - Fetches drivers with status=approved AND availability=available
  /// - Filters drivers who can accept orders
  /// - Returns list of eligible drivers
  ///
  /// **When to use:**
  /// - Automatic order assignment (find nearest available driver)
  /// - Admin dashboard (show available drivers count)
  /// - Manual order assignment UI
  ///
  /// **Filter criteria:**
  /// - status = approved (verified drivers only)
  /// - availability = available (not busy or offline)
  ///
  /// **Returns:**
  /// - Right(List<Driver>): List of available drivers (may be empty)
  /// - Left(DatabaseFailure): Database error
  /// - Left(NetworkFailure): Network error (if fetching from backend)
  ///
  /// **Example:**
  /// ```dart
  /// final result = await repository.getAvailableDrivers();
  /// result.fold(
  ///   (failure) => print('Failed to fetch drivers'),
  ///   (drivers) => print('${drivers.length} drivers available'),
  /// );
  /// ```
  Future<Either<Failure, List<Driver>>> getAvailableDrivers();

  /// Deletes a driver profile by driver ID
  ///
  /// **What it does:**
  /// - Deletes driver from backend API (soft delete)
  /// - Removes driver from local database
  /// - Cleans up driver-related data
  ///
  /// **When to use:**
  /// - Driver account closure (user request)
  /// - Admin removes fraudulent driver
  /// - Data cleanup (inactive drivers)
  ///
  /// **Parameters:**
  /// - [driverId]: Driver ID to delete
  ///
  /// **Returns:**
  /// - Right(true): Driver deleted successfully
  /// - Left(NotFoundFailure): Driver not found
  /// - Left(NetworkFailure): Network error
  /// - Left(ServerFailure): Backend error
  ///
  /// **Example:**
  /// ```dart
  /// final result = await repository.deleteDriver('drv_123');
  /// result.fold(
  ///   (failure) => showError('Failed to delete driver'),
  ///   (_) => showSuccess('Driver deleted'),
  /// );
  /// ```
  Future<Either<Failure, bool>> deleteDriver(String driverId);

  /// Deletes a driver profile by user ID
  ///
  /// **What it does:**
  /// - Looks up driver by user ID
  /// - Deletes driver from backend and local database
  /// - Cleans up driver-related data
  ///
  /// **When to use:**
  /// - User deletes their driver account
  /// - Account cleanup during user deletion
  ///
  /// **Parameters:**
  /// - [userId]: User account ID
  ///
  /// **Returns:**
  /// - Right(true): Driver deleted successfully
  /// - Left(NotFoundFailure): No driver profile for this user
  /// - Left(NetworkFailure): Network error
  /// - Left(ServerFailure): Backend error
  ///
  /// **Example:**
  /// ```dart
  /// final result = await repository.deleteDriverByUserId(userId);
  /// ```
  Future<Either<Failure, bool>> deleteDriverByUserId(String userId);

  /// Watches a driver by ID for real-time updates
  ///
  /// **What it does:**
  /// - Returns stream of driver updates
  /// - Emits new driver data when changes occur
  /// - Uses local database watch query
  /// - Emits null if driver not found or deleted
  ///
  /// **When to use:**
  /// - Driver profile screen (auto-update on changes)
  /// - Admin dashboard (real-time driver monitoring)
  /// - Driver status tracking
  ///
  /// **Parameters:**
  /// - [id]: Driver ID to watch
  ///
  /// **Returns:**
  /// - Stream<Driver?>: Emits driver updates or null
  ///
  /// **Example:**
  /// ```dart
  /// repository.watchDriverById('drv_123').listen((driver) {
  ///   if (driver != null) {
  ///     emit(DriverUpdated(driver));
  ///   } else {
  ///     emit(DriverNotFound());
  ///   }
  /// });
  /// ```
  Stream<Driver?> watchDriverById(String id);

  /// Watches a driver by user ID for real-time updates
  ///
  /// **What it does:**
  /// - Returns stream of driver updates
  /// - Emits new driver data when changes occur
  /// - Looks up driver by user ID
  /// - Emits null if no driver profile exists
  ///
  /// **When to use:**
  /// - Driver app (watch logged-in user's driver profile)
  /// - Auto-sync driver status changes
  /// - Real-time profile updates
  ///
  /// **Parameters:**
  /// - [userId]: User account ID to watch
  ///
  /// **Returns:**
  /// - Stream<Driver?>: Emits driver updates or null
  ///
  /// **Example:**
  /// ```dart
  /// // In driver app
  /// final userId = authRepository.getCurrentUserId();
  /// repository.watchDriverByUserId(userId).listen((driver) {
  ///   if (driver != null) {
  ///     emit(DriverProfileLoaded(driver));
  ///   }
  /// });
  /// ```
  Stream<Driver?> watchDriverByUserId(String userId);
}
