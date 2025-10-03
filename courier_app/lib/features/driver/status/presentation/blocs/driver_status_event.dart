import 'package:equatable/equatable.dart';
import 'package:delivery_app/features/drivers/domain/entities/driver.dart';

/// Base class for all driver status events
abstract class DriverStatusEvent extends Equatable {
  const DriverStatusEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load driver status from backend
class LoadDriverStatus extends DriverStatusEvent {}

/// Event to sync driver status with backend
///
/// Optionally pass current driver to check for status changes
class SyncDriverStatus extends DriverStatusEvent {
  final Driver? currentDriver;

  const SyncDriverStatus([this.currentDriver]);

  @override
  List<Object?> get props => [currentDriver];
}

/// Event to delete driver application
class DeleteDriverApplication extends DriverStatusEvent {}

/// Event to refresh driver status (reload from local DB and backend)
class RefreshDriverStatus extends DriverStatusEvent {}
