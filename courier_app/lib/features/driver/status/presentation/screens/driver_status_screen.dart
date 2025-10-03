import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:delivery_app/core/routing/route_names.dart';
import 'package:delivery_app/features/drivers/domain/entities/driver.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/driver_status.dart';
import '../blocs/driver_status_bloc.dart';
import '../blocs/driver_status_event.dart';
import '../blocs/driver_status_state.dart';
import '../widgets/status_card.dart';
import '../widgets/approval_dialog.dart';
import '../widgets/rejection_dialog.dart';
import '../widgets/suspension_dialog.dart';

/// Screen displaying driver application status with sync and action buttons
class DriverStatusScreen extends StatelessWidget {
  const DriverStatusScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) =>
            GetIt.instance<DriverStatusBloc>()..add(LoadDriverStatus()),
        child: const _DriverStatusView(),
      );
}

class _DriverStatusView extends StatelessWidget {
  const _DriverStatusView();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Driver Application Status'),
          actions: [
            BlocBuilder<DriverStatusBloc, DriverStatusState>(
              builder: (context, state) {
                final isSyncing = state is DriverStatusSyncing;
                final currentDriver = state is DriverStatusLoaded
                    ? state.driver
                    : state is DriverStatusSynced
                        ? state.driver
                        : null;

                return IconButton(
                  onPressed: isSyncing
                      ? null
                      : () => context.read<DriverStatusBloc>().add(
                            SyncDriverStatus(currentDriver),
                          ),
                  icon: isSyncing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.sync),
                  tooltip: 'Sync with server',
                );
              },
            ),
            IconButton(
              onPressed: () =>
                  context.read<DriverStatusBloc>().add(RefreshDriverStatus()),
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: BlocConsumer<DriverStatusBloc, DriverStatusState>(
          listener: (context, state) {
            // Handle status changes with dialogs
            if (state is DriverStatusSynced && state.statusChanged) {
              if (state.driver.status == DriverStatus.approved &&
                  state.previousStatus == DriverStatus.pending) {
                _showApprovalDialog(context, state.driver);
              } else if (state.driver.status == DriverStatus.rejected &&
                  state.previousStatus == DriverStatus.pending) {
                _showRejectionDialog(context, state.driver);
              } else if (state.driver.status == DriverStatus.suspended) {
                _showSuspensionDialog(context, state.driver);
              }
            }

            // Handle deletion
            if (state is DriverStatusDeleted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Driver application deleted successfully'),
                  backgroundColor: Colors.green,
                ),
              );
              context.go(RoutePaths.driverOnboarding);
            }

            // Handle errors
            if (state is DriverStatusError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is DriverStatusLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is DriverStatusError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => context
                          .read<DriverStatusBloc>()
                          .add(LoadDriverStatus()),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            if (state is DriverStatusLoaded || state is DriverStatusSynced) {
              final driver = state is DriverStatusLoaded
                  ? state.driver
                  : (state as DriverStatusSynced).driver;

              return StatusCard(
                driver: driver,
                onDelete: () => _showDeleteConfirmation(context),
              );
            }

            if (state is DriverStatusSyncing) {
              return Column(
                children: [
                  if (state.currentDriver != null)
                    Expanded(
                      child: StatusCard(
                        driver: state.currentDriver!,
                        onDelete: () => _showDeleteConfirmation(context),
                      ),
                    ),
                  const LinearProgressIndicator(),
                ],
              );
            }

            if (state is DriverStatusDeleting) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Deleting driver application...'),
                  ],
                ),
              );
            }

            return const Center(
              child: Text('No driver application found'),
            );
          },
        ),
      );

  void _showApprovalDialog(BuildContext context, Driver driver) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ApprovalDialog(
        driver: driver,
        onContinue: () {
          Navigator.of(dialogContext).pop();
          context.go(RoutePaths.driverHome);
        },
      ),
    );
  }

  void _showRejectionDialog(BuildContext context, Driver driver) {
    showDialog(
      context: context,
      builder: (dialogContext) => RejectionDialog(
        driver: driver,
        onReapply: () {
          Navigator.of(dialogContext).pop();
          context.go(RoutePaths.driverOnboarding);
        },
      ),
    );
  }

  void _showSuspensionDialog(BuildContext context, Driver driver) {
    showDialog(
      context: context,
      builder: (dialogContext) => SuspensionDialog(
        driver: driver,
        onContactSupport: () {
          Navigator.of(dialogContext).pop();
          context.go(RoutePaths.support);
        },
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Application'),
        content: const Text(
          'Are you sure you want to delete your driver application?\n\n'
          'This will remove all your driver information from the device and backend. '
          'You will need to reapply if you want to become a driver again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<DriverStatusBloc>().add(DeleteDriverApplication());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
