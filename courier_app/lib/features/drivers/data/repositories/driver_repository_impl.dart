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

/// Implementation of [DriverRepository] with offline-first pattern
///
/// This repository follows the offline-first approach:
/// 1. Always check local database first
/// 2. Return cached data immediately if available
/// 3. Queue write operations when offline
/// 4. Sync with backend when online
class DriverRepositoryImpl implements DriverRepository {
  final AppDatabase _database;
  final dynamic _apiClient; // ApiClient - using dynamic to avoid circular dependency

  DriverRepositoryImpl({
    required AppDatabase database,
    dynamic apiClient,
  })  : _database = database,
        _apiClient = apiClient;

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

  @override
  Future<Either<Failure, Driver>> fetchDriverFromBackend(String userId) async {
    try {
      if (_apiClient == null) {
        return const Left(
          NetworkFailure(message: 'API client not available'),
        );
      }

      // Fetch driver from backend
      final response = await _apiClient.get('/drivers/user/$userId');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;

        // Map backend response to Driver entity
        final driver = DriverMapper.fromBackendJson(data);

        // Save to local database (overwrites existing record)
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
        NetworkFailure(message: 'Failed to fetch driver from backend: ${e.toString()}'),
      );
    }
  }

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
          'endpoint': 'PUT /api/v1/drivers/$driverId/availability',
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
          'endpoint': 'PUT /api/v1/drivers/$driverId/location',
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
          'endpoint': 'PUT /api/v1/drivers/$driverId/location',
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
          'endpoint': 'DELETE /api/v1/drivers/$driverId',
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
            'endpoint': 'DELETE /api/v1/drivers/${driverData.id}',
            'data': null,
          }),
        );
      }

      return const Right(true);
    } catch (e) {
      return Left(
          CacheFailure(message: 'Failed to delete driver by user ID: ${e.toString()}'));
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
