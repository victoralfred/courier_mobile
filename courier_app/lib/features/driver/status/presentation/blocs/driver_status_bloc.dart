import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:delivery_app/core/error/failures.dart';
import 'package:delivery_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:delivery_app/features/driver/status/domain/usecases/sync_driver_status.dart'
    as usecases;
import 'package:delivery_app/features/driver/status/domain/usecases/delete_driver_application.dart'
    as usecases;
import 'driver_status_event.dart';
import 'driver_status_state.dart';

/// BLoC for managing driver status screen state
///
/// Handles:
/// - Loading driver status from backend
/// - Syncing with backend
/// - Detecting status changes
/// - Deleting driver application
class DriverStatusBloc extends Bloc<DriverStatusEvent, DriverStatusState> {
  final usecases.SyncDriverStatus syncDriverStatus;
  final usecases.DeleteDriverApplication deleteDriverApplication;
  final AuthRepository authRepository;

  DriverStatusBloc({
    required this.syncDriverStatus,
    required this.deleteDriverApplication,
    required this.authRepository,
  }) : super(DriverStatusInitial()) {
    on<LoadDriverStatus>(_onLoadDriverStatus);
    on<SyncDriverStatus>(_onSyncDriverStatus);
    on<DeleteDriverApplication>(_onDeleteDriverApplication);
    on<RefreshDriverStatus>(_onRefreshDriverStatus);
  }

  Future<void> _onLoadDriverStatus(
    LoadDriverStatus event,
    Emitter<DriverStatusState> emit,
  ) async {
    print('DriverStatusBloc: Loading driver status...');
    emit(DriverStatusLoading());

    // Get current user
    final userResult = await authRepository.getCurrentUser();

    await userResult.fold(
      (failure) async {
        emit(DriverStatusError(_mapFailureToMessage(failure)));
      },
      (user) async {
        // Sync from backend
        print('DriverStatusBloc: Syncing from backend for user: ${user.id.value}');
        final result = await syncDriverStatus(
          usecases.SyncDriverStatusParams(userId: user.id.value),
        );

        result.fold(
          (failure) {
            print('DriverStatusBloc: Sync failed - ${failure.runtimeType}: ${_mapFailureToMessage(failure)}');
            emit(DriverStatusError(_mapFailureToMessage(failure)));
          },
          (driver) {
            print('DriverStatusBloc: Driver loaded - Status: ${driver.status.name}');
            emit(DriverStatusLoaded(driver));
          },
        );
      },
    );
  }

  Future<void> _onSyncDriverStatus(
    SyncDriverStatus event,
    Emitter<DriverStatusState> emit,
  ) async {
    emit(DriverStatusSyncing(event.currentDriver));

    final userResult = await authRepository.getCurrentUser();

    await userResult.fold(
      (failure) async {
        emit(DriverStatusError(_mapFailureToMessage(failure)));
      },
      (user) async {
        final result = await syncDriverStatus(
          usecases.SyncDriverStatusParams(userId: user.id.value),
        );

        result.fold(
          (failure) => emit(DriverStatusError(_mapFailureToMessage(failure))),
          (driver) {
            final statusChanged = event.currentDriver != null &&
                event.currentDriver!.status != driver.status;

            emit(DriverStatusSynced(
              driver,
              statusChanged: statusChanged,
              previousStatus: event.currentDriver?.status,
            ));
          },
        );
      },
    );
  }

  Future<void> _onDeleteDriverApplication(
    DeleteDriverApplication event,
    Emitter<DriverStatusState> emit,
  ) async {
    emit(DriverStatusDeleting());

    final userResult = await authRepository.getCurrentUser();

    await userResult.fold(
      (failure) async {
        emit(DriverStatusError(_mapFailureToMessage(failure)));
      },
      (user) async {
        final result = await deleteDriverApplication(
          usecases.DeleteDriverApplicationParams(userId: user.id.value),
        );

        result.fold(
          (failure) => emit(DriverStatusError(_mapFailureToMessage(failure))),
          (_) => emit(DriverStatusDeleted()),
        );
      },
    );
  }

  Future<void> _onRefreshDriverStatus(
    RefreshDriverStatus event,
    Emitter<DriverStatusState> emit,
  ) async {
    // Simply re-load the status
    add(LoadDriverStatus());
  }

  String _mapFailureToMessage(Failure failure) {
    if (failure is NetworkFailure) {
      return failure.message;
    } else if (failure is ServerFailure) {
      return failure.message;
    } else if (failure is CacheFailure) {
      return failure.message;
    } else {
      return 'Unexpected error occurred';
    }
  }
}
