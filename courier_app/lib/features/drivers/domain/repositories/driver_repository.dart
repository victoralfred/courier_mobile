import 'package:dartz/dartz.dart';
import 'package:delivery_app/core/error/failures.dart';
import 'package:delivery_app/core/domain/value_objects/coordinate.dart';
import 'package:delivery_app/features/drivers/domain/entities/driver.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/availability_status.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/driver_status.dart';

/// Driver repository interface
/// Defines the contract for driver-related data operations
abstract class DriverRepository {
  /// Gets a driver by ID
  /// Returns [Driver] on success or [Failure] on error
  Future<Either<Failure, Driver>> getDriverById(String id);

  /// Gets a driver by user ID
  /// Returns [Driver] on success or [Failure] on error
  Future<Either<Failure, Driver>> getDriverByUserId(String userId);

  /// Creates or updates a driver profile
  /// Returns [Driver] on success or [Failure] on error
  Future<Either<Failure, Driver>> upsertDriver(Driver driver);

  /// Updates driver status (pending, approved, rejected, suspended)
  /// Returns [Driver] on success or [Failure] on error
  Future<Either<Failure, Driver>> updateStatus({
    required String driverId,
    required DriverStatus status,
  });

  /// Updates driver availability (offline, available, busy)
  /// Returns [Driver] on success or [Failure] on error
  Future<Either<Failure, Driver>> updateAvailability({
    required String driverId,
    required AvailabilityStatus availability,
  });

  /// Updates driver's current location
  /// Returns [Driver] on success or [Failure] on error
  Future<Either<Failure, Driver>> updateLocation({
    required String driverId,
    required Coordinate location,
  });

  /// Clears driver's location (when going offline)
  /// Returns [Driver] on success or [Failure] on error
  Future<Either<Failure, Driver>> clearLocation(String driverId);

  /// Updates driver rating
  /// Returns [Driver] on success or [Failure] on error
  Future<Either<Failure, Driver>> updateRating({
    required String driverId,
    required double rating,
    required int totalRatings,
  });

  /// Gets all available drivers (approved and available)
  /// Returns list of [Driver] on success or [Failure] on error
  Future<Either<Failure, List<Driver>>> getAvailableDrivers();

  /// Deletes a driver profile
  /// Returns [bool] on success or [Failure] on error
  Future<Either<Failure, bool>> deleteDriver(String driverId);

  /// Watches a driver by ID for real-time updates
  /// Returns a stream of [Driver] or null if not found
  Stream<Driver?> watchDriverById(String id);

  /// Watches a driver by user ID for real-time updates
  /// Returns a stream of [Driver] or null if not found
  Stream<Driver?> watchDriverByUserId(String userId);
}
