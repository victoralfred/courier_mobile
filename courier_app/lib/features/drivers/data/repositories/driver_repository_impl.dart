import 'package:dartz/dartz.dart';
import 'package:delivery_app/core/database/app_database.dart';
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

  DriverRepositoryImpl({required AppDatabase database}) : _database = database;

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
  Future<Either<Failure, Driver>> upsertDriver(Driver driver) async {
    try {
      // Convert domain entity to database model
      final driverData = DriverMapper.toDatabase(driver);

      // Save to local database
      await _database.driverDao.upsertDriver(driverData);

      // TODO: Queue for sync when network is available
      // await _queueSyncOperation(
      //   entityType: 'driver',
      //   entityId: driver.id,
      //   operation: 'upsert',
      //   payload: jsonEncode(driverData.toJson()),
      // );

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

      // TODO: Queue for sync when network is available

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

      // Get updated driver
      final result = await getDriverById(driverId);

      // TODO: Queue for sync when network is available

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

      // Get updated driver
      final result = await getDriverById(driverId);

      // TODO: Queue for sync when network is available

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

      // Get updated driver
      final result = await getDriverById(driverId);

      // TODO: Queue for sync when network is available

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

      // TODO: Queue for sync when network is available

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

      // TODO: Queue for sync when network is available
      // await _queueSyncOperation(
      //   entityType: 'driver',
      //   entityId: driverId,
      //   operation: 'delete',
      //   payload: jsonEncode({'id': driverId}),
      // );

      return const Right(true);
    } catch (e) {
      return Left(
          CacheFailure(message: 'Failed to delete driver: ${e.toString()}'));
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
