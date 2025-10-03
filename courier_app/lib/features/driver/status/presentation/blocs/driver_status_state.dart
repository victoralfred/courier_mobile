import 'package:equatable/equatable.dart';
import 'package:delivery_app/features/drivers/domain/entities/driver.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/driver_status.dart';

/// Base class for all driver status states
abstract class DriverStatusState extends Equatable {
  const DriverStatusState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any driver status is loaded
class DriverStatusInitial extends DriverStatusState {}

/// Loading driver status from backend
class DriverStatusLoading extends DriverStatusState {}

/// Driver status loaded successfully
class DriverStatusLoaded extends DriverStatusState {
  final Driver driver;

  const DriverStatusLoaded(this.driver);

  @override
  List<Object> get props => [driver];
}

/// Syncing driver status with backend
class DriverStatusSyncing extends DriverStatusState {
  final Driver? currentDriver;

  const DriverStatusSyncing([this.currentDriver]);

  @override
  List<Object?> get props => [currentDriver];
}

/// Driver status synced successfully
///
/// [statusChanged] indicates if the driver status changed during sync
/// [previousStatus] contains the status before sync (if changed)
class DriverStatusSynced extends DriverStatusState {
  final Driver driver;
  final bool statusChanged;
  final DriverStatus? previousStatus;

  const DriverStatusSynced(
    this.driver, {
    this.statusChanged = false,
    this.previousStatus,
  });

  @override
  List<Object?> get props => [driver, statusChanged, previousStatus];
}

/// Error occurred while loading/syncing driver status
class DriverStatusError extends DriverStatusState {
  final String message;

  const DriverStatusError(this.message);

  @override
  List<Object> get props => [message];
}

/// Deleting driver application
class DriverStatusDeleting extends DriverStatusState {}

/// Driver application deleted successfully
class DriverStatusDeleted extends DriverStatusState {}
