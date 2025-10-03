import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:delivery_app/core/routing/route_names.dart';
import 'package:delivery_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:delivery_app/features/drivers/domain/repositories/driver_repository.dart';
import 'package:delivery_app/features/drivers/domain/entities/driver.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/driver_status.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/vehicle_type.dart';
import 'package:delivery_app/core/network/connectivity_service.dart';

class DriverStatusScreen extends StatefulWidget {
  const DriverStatusScreen({super.key});

  @override
  State<DriverStatusScreen> createState() => _DriverStatusScreenState();
}

class _DriverStatusScreenState extends State<DriverStatusScreen> {
  Driver? _driver;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadDriverStatus();
  }

  Future<void> _loadDriverStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get current user
      final authRepository = GetIt.instance<AuthRepository>();
      final userResult = await authRepository.getCurrentUser();

      await userResult.fold(
        (failure) {
          setState(() {
            _errorMessage = 'Failed to load user: ${failure.message}';
            _isLoading = false;
          });
        },
        (user) async {
          // Get driver data
          final driverRepository = GetIt.instance<DriverRepository>();
          final driverResult =
              await driverRepository.getDriverByUserId(user.id.value);

          driverResult.fold(
            (failure) {
              setState(() {
                _errorMessage = 'No driver application found';
                _isLoading = false;
              });
            },
            (driver) {
              setState(() {
                _driver = driver;
                _isLoading = false;
              });
            },
          );
        },
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading status: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _syncWithBackend() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      final connectivityService = GetIt.instance<ConnectivityService>();
      final synced = await connectivityService.checkAndSync();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            synced
                ? 'Successfully synced with server'
                : 'No internet connection available',
          ),
          backgroundColor: synced ? Colors.green : Colors.orange,
        ),
      );

      // Reload status after sync
      await _loadDriverStatus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  Color _getStatusColor(DriverStatus status) {
    switch (status) {
      case DriverStatus.pending:
        return Colors.orange;
      case DriverStatus.approved:
        return Colors.green;
      case DriverStatus.rejected:
        return Colors.red;
      case DriverStatus.suspended:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(DriverStatus status) {
    switch (status) {
      case DriverStatus.pending:
        return Icons.hourglass_empty;
      case DriverStatus.approved:
        return Icons.check_circle;
      case DriverStatus.rejected:
        return Icons.cancel;
      case DriverStatus.suspended:
        return Icons.block;
    }
  }

  Widget _buildStatusCard() {
    if (_driver == null) {
      return const Center(
        child: Text(
          'No driver application found',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    final statusColor = _getStatusColor(_driver!.status);
    final statusIcon = _getStatusIcon(_driver!.status);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Card
          Card(
            elevation: 4,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    statusColor.withValues(alpha: 0.1),
                    statusColor.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      statusIcon,
                      size: 64,
                      color: statusColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Application Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _driver!.status.displayName.toUpperCase(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildStatusMessage(),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Driver Details
          Text(
            'Application Details',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          _buildDetailItem('Name', _driver!.fullName),
          _buildDetailItem('Email', _driver!.email),
          _buildDetailItem('Phone', _driver!.phone),
          _buildDetailItem('License Number', _driver!.licenseNumber),
          const SizedBox(height: 16),
          Text(
            'Vehicle Information',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          _buildDetailItem(
              'Vehicle Type', _driver!.vehicleInfo.type.displayName),
          _buildDetailItem('Make/Model',
              '${_driver!.vehicleInfo.make} ${_driver!.vehicleInfo.model}'),
          _buildDetailItem('Year', _driver!.vehicleInfo.year.toString()),
          _buildDetailItem('Color', _driver!.vehicleInfo.color),
          _buildDetailItem('License Plate', _driver!.vehicleInfo.plate),

          const SizedBox(height: 32),

          // Action Buttons
          if (_driver!.status == DriverStatus.approved) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.go(RoutePaths.driverHome);
                },
                icon: const Icon(Icons.dashboard),
                label: const Text('Go to Driver Dashboard'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ] else if (_driver!.status == DriverStatus.rejected) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.go(RoutePaths.driverOnboarding);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Reapply'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Delete Application Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _showDeleteConfirmation,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete Application'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusMessage() {
    String message;
    switch (_driver!.status) {
      case DriverStatus.pending:
        message =
            'Your application is under review. We will notify you within 24-48 hours.';
        break;
      case DriverStatus.approved:
        message =
            'Congratulations! Your application has been approved. You can now start accepting delivery requests.';
        break;
      case DriverStatus.rejected:
        message =
            'Unfortunately, your application was not approved. Please review the requirements and try again.';
        break;
      case DriverStatus.suspended:
        message =
            'Your driver account has been temporarily suspended. Please contact support for more information.';
        break;
    }

    return Text(
      message,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 14),
    );
  }

  Widget _buildDetailItem(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(
                '$label:',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Delete Application'),
        content: const Text(
          'Are you sure you want to delete your driver application?\n\n'
          'This will remove all your driver information from the device and backend. '
          'You will need to reapply if you want to become a driver again.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _deleteDriverApplication();
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

  Future<void> _deleteDriverApplication() async {
    try {
      // Get current user
      final authRepository = GetIt.instance<AuthRepository>();
      final userResult = await authRepository.getCurrentUser();

      await userResult.fold(
        (failure) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to get user: ${failure.message}'),
              backgroundColor: Colors.red,
            ),
          );
        },
        (user) async {
          // Delete driver by user ID
          final driverRepository = GetIt.instance<DriverRepository>();
          final result = await driverRepository.deleteDriverByUserId(user.id.value);

          if (!mounted) return;

          result.fold(
            (failure) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to delete application: ${failure.message}'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Driver application deleted successfully'),
                  backgroundColor: Colors.green,
                ),
              );

              // Navigate to driver onboarding
              context.go(RoutePaths.driverOnboarding);
            },
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting application: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Driver Application Status'),
          actions: [
            IconButton(
              onPressed: _isSyncing ? null : _syncWithBackend,
              icon: _isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.sync),
              tooltip: 'Sync with server',
            ),
            IconButton(
              onPressed: _loadDriverStatus,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadDriverStatus,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _buildStatusCard(),
      );
}
