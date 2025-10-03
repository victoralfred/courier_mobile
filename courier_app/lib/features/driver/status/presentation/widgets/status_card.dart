import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delivery_app/core/routing/route_names.dart';
import 'package:delivery_app/features/drivers/domain/entities/driver.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/driver_status.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/vehicle_type.dart';

/// Widget displaying driver application status with details and action buttons
class StatusCard extends StatelessWidget {
  final Driver driver;
  final VoidCallback onDelete;

  const StatusCard({
    super.key,
    required this.driver,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(driver.status);
    final statusIcon = _getStatusIcon(driver.status);

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
                    Icon(statusIcon, size: 64, color: statusColor),
                    const SizedBox(height: 16),
                    Text(
                      'Application Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      driver.status.displayName.toUpperCase(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildStatusMessage(context),
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
          _buildDetailItem('Name', driver.fullName),
          _buildDetailItem('Email', driver.email),
          _buildDetailItem('Phone', driver.phone),
          _buildDetailItem('License Number', driver.licenseNumber),
          const SizedBox(height: 16),
          Text(
            'Vehicle Information',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          _buildDetailItem('Vehicle Type', driver.vehicleInfo.type.displayName),
          _buildDetailItem(
            'Make/Model',
            '${driver.vehicleInfo.make} ${driver.vehicleInfo.model}',
          ),
          _buildDetailItem('Year', driver.vehicleInfo.year.toString()),
          _buildDetailItem('Color', driver.vehicleInfo.color),
          _buildDetailItem('License Plate', driver.vehicleInfo.plate),

          const SizedBox(height: 32),

          // Action Buttons based on status
          ..._buildActionButtons(context),

          const SizedBox(height: 16),

          // Delete Application Button (not shown for suspended)
          if (driver.status != DriverStatus.suspended)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: onDelete,
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

  Widget _buildStatusMessage(BuildContext context) {
    switch (driver.status) {
      case DriverStatus.pending:
        return const Text(
          'Your application is under review. We will notify you within 24-48 hours.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14),
        );
      case DriverStatus.approved:
        return const Text(
          'Congratulations! Your application has been approved. You can now start accepting delivery requests.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14),
        );
      case DriverStatus.rejected:
        return Column(
          children: [
            const Text(
              'Unfortunately, your application was not approved.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            if (driver.rejectionReason != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reason:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red[900],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      driver.rejectionReason!,
                      style: TextStyle(color: Colors.red[800]),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Please review the requirements and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        );
      case DriverStatus.suspended:
        return Column(
          children: [
            const Text(
              'Your driver account has been temporarily suspended.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            if (driver.suspensionReason != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Suspension Reason:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(driver.suspensionReason!),
                    if (driver.suspensionExpiresAt != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Suspension ends: ${_formatDate(driver.suspensionExpiresAt!)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Please contact support for more information.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        );
    }
  }

  List<Widget> _buildActionButtons(BuildContext context) {
    switch (driver.status) {
      case DriverStatus.approved:
        return [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => context.go(RoutePaths.driverHome),
              icon: const Icon(Icons.dashboard),
              label: const Text('Go to Driver Dashboard'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ];
      case DriverStatus.rejected:
        return [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => context.go(RoutePaths.driverOnboarding),
              icon: const Icon(Icons.refresh),
              label: const Text('Reapply'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ];
      case DriverStatus.suspended:
        return [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => context.go(RoutePaths.support),
              icon: const Icon(Icons.support_agent),
              label: const Text('Contact Support'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[700],
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ];
      default:
        return [];
    }
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

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
}
