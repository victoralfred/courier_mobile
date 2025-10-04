import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:delivery_app/core/error/failures.dart';
import 'package:delivery_app/core/usecases/usecase.dart';
import 'package:delivery_app/features/drivers/domain/repositories/driver_repository.dart';

/// Use case for deleting driver application
///
/// This use case deletes the driver application from:
/// 1. Local database
/// 2. Backend server (via sync queue)
///
/// Returns [bool] on success
class DeleteDriverApplication
    implements UseCase<bool, DeleteDriverApplicationParams> {
  final DriverRepository repository;

  DeleteDriverApplication({
    required this.repository,
  });

  @override
  Future<Either<Failure, bool>> call(
      DeleteDriverApplicationParams params) async =>
      repository.deleteDriverByUserId(params.userId);
}

/// Parameters for DeleteDriverApplication use case
class DeleteDriverApplicationParams extends Equatable {
  final String userId;

  const DeleteDriverApplicationParams({required this.userId});

  @override
  List<Object> get props => [userId];
}
