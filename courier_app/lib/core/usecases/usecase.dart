import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:delivery_app/core/error/failures.dart';

/// Base class for all use cases
abstract class UseCase<ObjectType, Params> {
  /// Executes the use case
  Future<Either<Failure, ObjectType>> call(Params params);
}

/// Parameters class for use cases that don't require parameters
class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object> get props => [];
}
