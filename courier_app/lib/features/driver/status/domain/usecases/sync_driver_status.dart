import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:delivery_app/core/error/failures.dart';
import 'package:delivery_app/core/network/connectivity_service.dart';
import 'package:delivery_app/core/usecases/usecase.dart';
import 'package:delivery_app/features/drivers/domain/entities/driver.dart';
import 'package:delivery_app/features/drivers/domain/repositories/driver_repository.dart';

/// Use case for syncing driver status from backend
///
/// This use case:
/// 1. Checks internet connectivity
/// 2. Fetches latest driver data from backend
/// 3. Updates local database with fetched data
///
/// Returns [NetworkFailure] if offline or connection fails
class SyncDriverStatus implements UseCase<Driver, SyncDriverStatusParams> {
  final DriverRepository repository;
  final ConnectivityService connectivity;

  SyncDriverStatus({
    required this.repository,
    required this.connectivity,
  });

  @override
  Future<Either<Failure, Driver>> call(SyncDriverStatusParams params) async {
    // Check connectivity
    final isOnline = await connectivity.isOnline();

    if (!isOnline) {
      return const Left(NetworkFailure(
        message: 'No internet connection. Cannot sync with server.',
      ));
    }

    // Fetch from backend (this also updates local DB)
    return repository.fetchDriverFromBackend(params.userId);
  }
}

/// Parameters for SyncDriverStatus use case
class SyncDriverStatusParams extends Equatable {
  final String userId;

  const SyncDriverStatusParams({required this.userId});

  @override
  List<Object> get props => [userId];
}
