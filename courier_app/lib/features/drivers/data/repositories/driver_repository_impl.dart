import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:delivery_app/core/database/app_database.dart';
import 'package:delivery_app/core/database/extensions/driver_table_extensions.dart';
import 'package:delivery_app/core/domain/value_objects/coordinate.dart';
import 'package:delivery_app/core/error/failures.dart';
import 'package:delivery_app/features/drivers/data/mappers/driver_mapper.dart';
import 'package:delivery_app/features/drivers/domain/entities/driver.dart';
import 'package:delivery_app/features/drivers/domain/repositories/driver_repository.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/availability_status.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/driver_status.dart';

/// [DriverRepositoryImpl] - Complete driver repository implementation with offline-first architecture
///
/// **What it does:**
/// - Implements DriverRepository interface with real data sources
/// - Orchestrates offline-first driver data management
/// - Handles local database operations (SQLite/Drift)
/// - Manages backend API synchronization
/// - Queues write operations for offline sync
/// - Provides real-time driver updates via streams
/// - Converts between domain entities and database models
/// - Handles driver CRUD operations with sync queue
///
/// **Why it exists:**
/// - Implements domain repository contract with actual platform code
/// - Bridges domain layer (use cases) and data layer (database/API)
/// - Enables offline capability for driver management
/// - Centralizes driver data orchestration logic
/// - Provides clean error handling via Either<Failure, T>
/// - Enables testability through dependency injection
/// - Separates concerns: domain doesn't know about database/network
///
/// **Architecture (Offline-First Repository Pattern):**
/// ```
/// Presentation Layer (BLoC/Cubit)
///          ↓
/// Domain Layer (Use Cases)
///          ↓
/// Domain Repository Interface
///          ↓
/// Data Repository Implementation ← YOU ARE HERE
///          ↓
/// ├─ AppDatabase (Drift/SQLite)
/// │  ├─ DriverDao (CRUD queries)
/// │  └─ SyncQueueDao (offline sync)
/// │
/// └─ ApiClient (HTTP/REST)
///    └─ Backend API endpoints
/// ```
///
/// **Offline-First Strategy:**
/// ```
/// READ Operations (getDriverById, getDriverByUserId):
///   1. Query local database FIRST (instant response)
///   2. Return cached driver immediately
///   3. No network call (use fetchDriverFromBackend for sync)
///   4. Works completely offline
///
/// WRITE Operations (upsertDriver, updateAvailability, updateLocation):
///   1. Save to local database immediately
///   2. Add operation to sync queue
///   3. Return success (optimistic update)
///   4. Background worker syncs when online
///
/// SYNC Operations (fetchDriverFromBackend):
///   1. Fetch from backend API
///   2. Delete existing local records (prevent duplicates)
///   3. Save fresh data to local database
///   4. Return updated driver
///
/// REAL-TIME Operations (watchDriverById, watchDriverByUserId):
///   1. Watch local database (reactive stream)
///   2. Emit new data when local changes occur
///   3. Backend sync updates local DB → stream emits
/// ```
///
/// **Data Flow (Driver Onboarding - Create New Driver):**
/// ```
/// upsertDriver(newDriver)
///       ↓
/// Check if driver exists in local DB
///   ↙                          ↘
/// NOT FOUND                 FOUND
///   ↓                          ↓
/// Save to local DB         Save to local DB
///   ↓                          ↓
/// Add to sync queue:       Add to sync queue:
/// operation='create'       operation='update'
/// endpoint='POST /drivers' endpoint='PUT /drivers/:id'
///   ↓                          ↓
/// Return Right(driver)     Return Right(driver)
///       ↓
/// Background worker syncs when online:
///   ↓
/// POST /drivers/register {...driverJson}
///   ↓
/// Backend creates driver → returns ID
///   ↓
/// Update local DB with backend ID
///   ↓
/// Mark sync queue item as completed
/// ```
///
/// **Data Flow (Location Update - Real-time Tracking):**
/// ```
/// updateLocation(driverId, gpsCoords)
///       ↓
/// Update local DB (driverDao.updateLocation)
///       ↓
/// Add to sync queue:
/// operation='update_location'
/// endpoint='PUT /drivers/:id/location'
/// payload={latitude, longitude, timestamp}
///       ↓
/// Get updated driver from local DB
///       ↓
/// Return Right(driver)
///       ↓
/// watchDriverById stream emits new location
///       ↓
/// Background worker syncs:
///   ↓
/// PUT /drivers/:id/location
///   ↓
/// Backend updates driver location
///   ↓
/// WebSocket notifies admin dashboard
///   ↓
/// Mark sync queue item as completed
/// ```
///
/// **Data Flow (Fetch from Backend - Sync Remote Data):**
/// ```
/// fetchDriverFromBackend(userId)
///       ↓
/// Check ApiClient availability
///       ↓
/// GET /drivers/:userId (with auth token)
///       ↓
/// Receive response
///   ↙           ↘
/// 200 OK       404/500
///   ↓             ↓
/// Extract data  Return Left(Failure)
///   ↓
/// Map backend JSON → Driver entity
///   ↓
/// Delete existing driver records (prevent duplicates)
///   ↓
/// Save fresh driver to local DB
///   ↓
/// Return Right(driver)
/// ```
///
/// **Sync Queue Payloads:**
/// ```
/// CREATE (driver onboarding):
/// {
///   "endpoint": "POST /drivers/register",
///   "data": {
///     "user_id": "usr_123",
///     "first_name": "Amaka",
///     "last_name": "Nwosu",
///     "email": "amaka@example.com",
///     "phone_number": "+2348098765432",
///     "license_number": "LAG-67890-XY",
///     "vehicle": {
///       "plate": "ABC-123-XY",
///       "type": "motorcycle",
///       "make": "Honda",
///       "model": "CB500X",
///       "year": 2023,
///       "color": "Red"
///     }
///   }
/// }
///
/// UPDATE AVAILABILITY:
/// {
///   "endpoint": "PUT /drivers/:id/availability",
///   "data": {
///     "availability": "available"
///   }
/// }
///
/// UPDATE LOCATION:
/// {
///   "endpoint": "PUT /drivers/:id/location",
///   "data": {
///     "latitude": 6.5244,
///     "longitude": 3.3792,
///     "timestamp": "2025-10-04T14:30:00Z"
///   }
/// }
///
/// DELETE:
/// {
///   "endpoint": "DELETE /drivers/:id",
///   "data": null
/// }
/// ```
///
/// **Error Handling Pattern:**
/// - Uses Either<Failure, T> from dartz package
/// - Left(CacheFailure): Database errors
/// - Left(NetworkFailure): API errors
/// - Right(T): Success value (Driver, List<Driver>, bool)
/// - No exceptions thrown (all errors as Failure types)
///
/// **Usage Example:**
/// ```dart
/// // Create driver (offline-capable)
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
/// result.fold(
///   (failure) => showError(failure.message),
///   (driver) => navigateToPendingApproval(driver),
/// );
///
/// // Sync from backend (online)
/// final syncResult = await repository.fetchDriverFromBackend(userId);
/// syncResult.fold(
///   (failure) => print('Sync failed: ${failure.message}'),
///   (driver) => print('Synced: ${driver.fullName}'),
/// );
///
/// // Real-time location updates
/// Timer.periodic(Duration(seconds: 15), (_) async {
///   final location = await gpsService.getCurrentLocation();
///   await repository.updateLocation(
///     driverId: driver.id,
///     location: location,
///   );
/// });
///
/// // Watch for updates
/// repository.watchDriverByUserId(userId).listen((driver) {
///   if (driver != null) {
///     emit(DriverUpdated(driver));
///   }
/// });
/// ```
///
/// **Dependency Injection:**
/// - @LazySingleton: Single instance created on first use
/// - Injectable: Auto-registered with get_it service locator
/// - Constructor injection: All dependencies provided externally
///
/// **IMPROVEMENTS:**
/// - [High Priority] Extract backend sync logic to separate SyncService
/// - Currently mixing repository logic with sync queue management
/// - [High Priority] Add retry logic for failed sync operations
/// - Exponential backoff for network errors
/// - [Medium Priority] Add conflict resolution for concurrent updates
/// - Last-write-wins vs merge strategies
/// - [Medium Priority] Add batch sync operations
/// - Sync multiple drivers in single API call
/// - [Low Priority] Add driver data versioning
/// - Detect when server driver model has changed
/// - [Low Priority] Add sync progress callbacks
/// - Notify UI about sync status
class DriverRepositoryImpl implements DriverRepository {
  final AppDatabase _database;
  final dynamic
      _apiClient; // ApiClient - using dynamic to avoid circular dependency

  /// Creates DriverRepositoryImpl with required dependencies
  ///
  /// **Parameters:**
  /// - [database]: Drift database instance for local storage (required)
  /// - [apiClient]: HTTP client for backend API calls (optional, uses dynamic to avoid circular dependency)
  ///
  /// **Initialization:**
  /// - Stores database reference for data persistence
  /// - Stores API client for backend synchronization
  /// - No upfront data loading (lazy loading pattern)
  ///
  /// **Example:**
  /// ```dart
  /// final repository = DriverRepositoryImpl(
  ///   database: GetIt.I<AppDatabase>(),
  ///   apiClient: GetIt.I<ApiClient>(),
  /// );
  /// ```
  DriverRepositoryImpl({
    required AppDatabase database,
    dynamic apiClient,
  })  : _database = database,
        _apiClient = apiClient;

  /// Gets driver by ID from local database (offline-first)
  ///
  /// **What it does:**
  /// - Queries local Drift database for driver record
  /// - Maps database model to domain entity
  /// - Returns cached driver (no network call)
  /// - Fast lookup for driver profile display
  ///
  /// **Flow:**
  /// ```
  /// Query local DB (driverDao.getDriverById)
  ///       ↓
  /// Found? → Map to Driver entity → Return Right(driver)
  /// Not found? → Return Left(CacheFailure)
  /// Error? → Return Left(CacheFailure)
  /// ```
  ///
  /// **Parameters:**
  /// - [id]: Driver ID (not user ID)
  ///
  /// **Returns:**
  /// - Right(Driver): Driver found in local database
  /// - Left(CacheFailure): Driver not found or database error
  ///
  /// **Example:**
  /// ```dart
  /// final result = await repository.getDriverById('drv_123');
  /// result.fold(
  ///   (failure) => showError('Driver not found'),
  ///   (driver) => displayDriverProfile(driver),
  /// );
  /// ```
  @override
  Future<Either<Failure, Driver>> getDriverById(String id) async {
    try {
      // Try to get from local database first (offline-first)
      final driverData = await _database.driverDao.getDriverById(id);

      if (driverData == null) {
        return const Left(
            CacheFailure(message: 'Driver not found in local database'));
      }

      final driver = DriverMapper.fromDatabase(driverData);
      return Right(driver);
    } catch (e) {
      return Left(
          CacheFailure(message: 'Failed to get driver: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Driver>> getDriverByUserId(String userId) async {
    try {
      // Try to get from local database first (offline-first)
      final driverData = await _database.driverDao.getDriverByUserId(userId);

      if (driverData == null) {
        return const Left(CacheFailure(
            message: 'Driver not found for user in local database'));
      }

      final driver = DriverMapper.fromDatabase(driverData);
      return Right(driver);
    } catch (e) {
      return Left(CacheFailure(
          message: 'Failed to get driver by user ID: ${e.toString()}'));
    }
  }

  /// Fetches driver from backend API and syncs to local database
  ///
  /// **What it does:**
  /// - Fetches fresh driver data from backend REST API
  /// - Deletes existing local driver records (prevents duplicates)
  /// - Saves fresh data to local database
  /// - Returns updated driver entity
  ///
  /// **When to use:**
  /// - User login (sync remote driver profile)
  /// - Pull-to-refresh driver profile
  /// - Verify driver status after admin approval
  /// - Periodic background sync
  ///
  /// **Flow:**
  /// ```
  /// Check ApiClient availability
  ///       ↓
  /// GET /drivers/{userId} (with auth token)
  ///       ↓
  /// Receive JSON response
  ///   ↙           ↘
  /// 200 OK       404/500
  ///   ↓             ↓
  /// Extract data  Return NetworkFailure
  ///   ↓
  /// Map backend JSON → Driver entity (DriverMapper.fromBackendJson)
  ///   ↓
  /// Delete existing driver records by userId (prevent duplicates)
  ///       ↓
  /// Save fresh driver to local DB (driverDao.upsertDriver)
  ///       ↓
  /// Return Right(driver)
  /// ```
  ///
  /// **API Endpoint:**
  /// - URL: GET /drivers/{userId}
  /// - Auth: Required (Bearer token)
  /// - Response: `{ "data": { "id": "...", "user_id": "...", "first_name": "...", ... } }`
  ///
  /// **Parameters:**
  /// - [userId]: User account ID (from authentication)
  ///
  /// **Returns:**
  /// - Right(Driver): Driver fetched and synced successfully
  /// - Left(NetworkFailure): API client unavailable, network error, or HTTP error
  /// - Left(CacheFailure): Database save error
  ///
  /// **Edge Cases:**
  /// - ApiClient is null → NetworkFailure
  /// - 404 response → NetworkFailure (driver not found on backend)
  /// - Network timeout → NetworkFailure
  /// - Database save fails → CacheFailure
  ///
  /// **Example:**
  /// ```dart
  /// // Sync driver on app startup
  /// final result = await repository.fetchDriverFromBackend(userId);
  /// result.fold(
  ///   (failure) {
  ///     if (failure is NetworkFailure) {
  ///       print('Network error: ${failure.message}');
  ///       // Continue with cached data
  ///     }
  ///   },
  ///   (driver) => print('Synced: ${driver.fullName}, Status: ${driver.status.name}'),
  /// );
  /// ```
  @override
  Future<Either<Failure, Driver>> fetchDriverFromBackend(String userId) async {
    try {
      if (_apiClient == null) {
        return const Left(
          NetworkFailure(message: 'API client not available'),
        );
      }

      // Fetch driver from backend
      final response = await _apiClient.get('/drivers/$userId');

      if (response.statusCode == 200 && response.data != null) {
        final responseData = response.data as Map<String, dynamic>;

        // Extract the actual driver data from the wrapper
        final data = responseData['data'] as Map<String, dynamic>;

        // Map backend response to Driver entity
        final driver = DriverMapper.fromBackendJson(data);

        // Delete any existing driver records for this user to prevent duplicates
        await _database.driverDao.deleteDriverByUserId(userId);

        // Save fresh record to local database
        final driverData = DriverMapper.toDatabase(driver);
        await _database.driverDao.upsertDriver(driverData);

        return Right(driver);
      } else if (response.statusCode == 404) {
        return const Left(
          NetworkFailure(message: 'Driver not found on backend'),
        );
      } else {
        return Left(
          NetworkFailure(
            message: 'Failed to fetch driver: HTTP ${response.statusCode}',
          ),
        );
      }
    } catch (e) {
      return Left(
        NetworkFailure(
            message: 'Failed to fetch driver from backend: ${e.toString()}'),
      );
    }
  }

  /// Creates or updates driver profile with offline-first sync
  ///
  /// **What it does:**
  /// - Creates new driver if doesn't exist
  /// - Updates existing driver if already exists
  /// - Saves to local database immediately (optimistic update)
  /// - Queues operation for backend sync when online
  /// - Returns driver entity
  ///
  /// **When to use:**
  /// - Driver onboarding (create new driver profile)
  /// - Driver profile update (edit vehicle info, contact details)
  /// - Offline driver creation (sync later when online)
  ///
  /// **Flow:**
  /// ```
  /// Convert Driver entity → DriverTableData (DriverMapper.toDatabase)
  ///       ↓
  /// Check if driver exists in local DB
  ///   ↙                          ↘
  /// NOT FOUND                 FOUND
  /// (New driver)            (Update driver)
  ///   ↓                          ↓
  /// Save to local DB         Save to local DB
  ///   ↓                          ↓
  /// Add to sync queue:       Add to sync queue:
  /// operation='create'       operation='update'
  /// endpoint='POST /drivers/register'  endpoint='PUT /drivers/{id}'
  /// payload=registrationJson   payload=updateJson
  ///   ↓                          ↓
  /// Return Right(driver)     Return Right(driver)
  ///       ↓
  /// Background worker syncs when online
  /// ```
  ///
  /// **Sync Queue Payloads:**
  /// ```
  /// CREATE (new driver onboarding):
  /// {
  ///   "endpoint": "POST /drivers/register",
  ///   "data": {
  ///     "user_id": "usr_123",
  ///     "first_name": "Amaka",
  ///     "last_name": "Nwosu",
  ///     "email": "amaka@example.com",
  ///     "phone_number": "+2348098765432",
  ///     "license_number": "LAG-67890-XY",
  ///     "vehicle": {
  ///       "plate": "ABC-123-XY",
  ///       "type": "motorcycle",
  ///       "make": "Honda",
  ///       "model": "CB500X",
  ///       "year": 2023,
  ///       "color": "Red"
  ///     }
  ///   }
  /// }
  ///
  /// UPDATE (existing driver):
  /// {
  ///   "endpoint": "PUT /drivers/{driverId}",
  ///   "data": {
  ///     "first_name": "Amaka",
  ///     "vehicle": { ... }
  ///   }
  /// }
  /// ```
  ///
  /// **Parameters:**
  /// - [driver]: Driver entity to create/update
  ///
  /// **Returns:**
  /// - Right(Driver): Driver created/updated successfully in local DB
  /// - Left(CacheFailure): Database save error
  ///
  /// **Edge Cases:**
  /// - Offline creation → Saved locally, syncs when online
  /// - Duplicate driver ID → Updates existing record
  /// - Sync fails → Retried by background worker
  ///
  /// **Example:**
  /// ```dart
  /// // Create new driver (offline-capable)
  /// final newDriver = Driver(
  ///   id: uuid.v4(),
  ///   userId: currentUser.id,
  ///   firstName: 'Amaka',
  ///   lastName: 'Nwosu',
  ///   email: 'amaka@example.com',
  ///   phone: '+2348098765432',
  ///   licenseNumber: 'LAG-67890-XY',
  ///   vehicleInfo: VehicleInfo(
  ///     plate: 'ABC-123-XY',
  ///     type: VehicleType.motorcycle,
  ///     make: 'Honda',
  ///     model: 'CB500X',
  ///     year: 2023,
  ///     color: 'Red',
  ///   ),
  ///   status: DriverStatus.pending,
  ///   availability: AvailabilityStatus.offline,
  ///   rating: 0.0,
  ///   totalRatings: 0,
  /// );
  ///
  /// final result = await repository.upsertDriver(newDriver);
  /// result.fold(
  ///   (failure) => showError(failure.message),
  ///   (driver) => navigateToPendingApproval(driver),
  /// );
  /// ```
  @override
  Future<Either<Failure, Driver>> upsertDriver(Driver driver) async {
    try {
      // Convert domain entity to database model
      final driverData = DriverMapper.toDatabase(driver);

      // Check if driver already exists
      final existing = await _database.driverDao.getDriverById(driver.id);

      // Save to local database
      await _database.driverDao.upsertDriver(driverData);

      // Queue for sync when network is available
      if (existing == null) {
        // New driver - queue CREATE operation (register)
        await _database.syncQueueDao.addToQueue(
          entityType: 'driver',
          entityId: driver.id,
          operation: 'create',
          payload: jsonEncode({
            'endpoint': 'POST /drivers/register',
            'data': driverData.toRegistrationJson(),
          }),
        );
      } else {
        // Existing driver - queue UPDATE operation
        await _database.syncQueueDao.addToQueue(
          entityType: 'driver',
          entityId: driver.id,
          operation: 'update',
          payload: jsonEncode({
            'endpoint': 'PUT /drivers/${driver.id}',
            'data': driverData.toUpdateJson(),
          }),
        );
      }

      return Right(driver);
    } catch (e) {
      return Left(
          CacheFailure(message: 'Failed to save driver: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Driver>> updateStatus({
    required String driverId,
    required DriverStatus status,
  }) async {
    try {
      // Update in local database
      await _database.driverDao.updateStatus(driverId, status.name);

      // Get updated driver
      final result = await getDriverById(driverId);

      // Note: Status updates (approve/reject) are typically admin actions
      // and may not need to sync from mobile app. If needed, implement
      // PUT /api/v1/drivers/:driverId/status endpoint on backend.

      return result;
    } catch (e) {
      return Left(CacheFailure(
          message: 'Failed to update driver status: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Driver>> updateAvailability({
    required String driverId,
    required AvailabilityStatus availability,
  }) async {
    try {
      // Update in local database
      await _database.driverDao.updateAvailability(driverId, availability.name);

      // Queue for sync when network is available
      await _database.syncQueueDao.addToQueue(
        entityType: 'driver',
        entityId: driverId,
        operation: 'update_availability',
        payload: jsonEncode({
          'endpoint': 'PUT /drivers/$driverId/availability',
          'data': {'availability': availability.name},
        }),
      );

      // Get updated driver
      final result = await getDriverById(driverId);

      return result;
    } catch (e) {
      return Left(CacheFailure(
          message: 'Failed to update driver availability: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Driver>> updateLocation({
    required String driverId,
    required Coordinate location,
  }) async {
    try {
      // Update in local database
      await _database.driverDao.updateLocation(
        driverId: driverId,
        latitude: location.latitude,
        longitude: location.longitude,
      );

      // Queue for sync when network is available
      await _database.syncQueueDao.addToQueue(
        entityType: 'driver',
        entityId: driverId,
        operation: 'update_location',
        payload: jsonEncode({
          'endpoint': 'PUT /drivers/$driverId/location',
          'data': {
            'latitude': location.latitude,
            'longitude': location.longitude,
            'timestamp': DateTime.now().toIso8601String(),
          },
        }),
      );

      // Get updated driver
      final result = await getDriverById(driverId);

      return result;
    } catch (e) {
      return Left(CacheFailure(
          message: 'Failed to update driver location: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Driver>> clearLocation(String driverId) async {
    try {
      // Clear location in local database
      await _database.driverDao.clearLocation(driverId);

      // Queue for sync when network is available
      // Clearing location is essentially setting it to null
      await _database.syncQueueDao.addToQueue(
        entityType: 'driver',
        entityId: driverId,
        operation: 'update_location',
        payload: jsonEncode({
          'endpoint': 'PUT /drivers/$driverId/location',
          'data': {
            'latitude': null,
            'longitude': null,
            'timestamp': DateTime.now().toIso8601String(),
          },
        }),
      );

      // Get updated driver
      final result = await getDriverById(driverId);

      return result;
    } catch (e) {
      return Left(CacheFailure(
          message: 'Failed to clear driver location: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Driver>> updateRating({
    required String driverId,
    required double rating,
    required int totalRatings,
  }) async {
    try {
      // Update in local database
      await _database.driverDao.updateRating(
        driverId: driverId,
        rating: rating,
        totalRatings: totalRatings,
      );

      // Get updated driver
      final result = await getDriverById(driverId);

      // Note: Ratings are typically calculated server-side based on customer reviews
      // and should not be directly updated from mobile app. This method is mainly
      // for updating local cache when fetching from server.

      return result;
    } catch (e) {
      return Left(CacheFailure(
          message: 'Failed to update driver rating: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Driver>>> getAvailableDrivers() async {
    try {
      // Get from local database (offline-first)
      final driversData = await _database.driverDao.getAvailableDrivers();

      final drivers = driversData.map(DriverMapper.fromDatabase).toList();

      return Right(drivers);
    } catch (e) {
      return Left(CacheFailure(
          message: 'Failed to get available drivers: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> deleteDriver(String driverId) async {
    try {
      // Delete from local database
      await _database.driverDao.deleteDriver(driverId);

      // Queue for sync when network is available
      await _database.syncQueueDao.addToQueue(
        entityType: 'driver',
        entityId: driverId,
        operation: 'delete',
        payload: jsonEncode({
          'endpoint': 'DELETE /drivers/$driverId',
          'data': null,
        }),
      );

      return const Right(true);
    } catch (e) {
      return Left(
          CacheFailure(message: 'Failed to delete driver: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> deleteDriverByUserId(String userId) async {
    try {
      // First, get the driver to find the driver ID for sync queue
      final driverData = await _database.driverDao.getDriverByUserId(userId);

      // Delete from local database
      await _database.driverDao.deleteDriverByUserId(userId);

      // Queue for sync when network is available (if driver exists)
      if (driverData != null) {
        await _database.syncQueueDao.addToQueue(
          entityType: 'driver',
          entityId: driverData.id,
          operation: 'delete',
          payload: jsonEncode({
            'endpoint': 'DELETE /drivers/${driverData.id}',
            'data': null,
          }),
        );
      }

      return const Right(true);
    } catch (e) {
      return Left(CacheFailure(
          message: 'Failed to delete driver by user ID: ${e.toString()}'));
    }
  }

  @override
  Stream<Driver?> watchDriverById(String id) =>
      _database.driverDao.watchDriverById(id).map((driverData) {
        if (driverData == null) return null;
        return DriverMapper.fromDatabase(driverData);
      });

  @override
  Stream<Driver?> watchDriverByUserId(String userId) =>
      _database.driverDao.watchDriverByUserId(userId).map((driverData) {
        if (driverData == null) return null;
        return DriverMapper.fromDatabase(driverData);
      });
}
