import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delivery_app/core/routing/route_names.dart';
import 'package:delivery_app/features/drivers/domain/entities/driver.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/driver_status.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/vehicle_type.dart';

/// Widget displaying driver application status with details and action buttons
class StatusCard extends StatefulWidget {
  final Driver driver;
  final VoidCallback onDelete;

  const StatusCard({
    super.key,
    required this.driver,
    required this.onDelete,
  });

  @override
  State<StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends State<StatusCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(widget.driver.status);
    final statusIcon = _getStatusIcon(widget.driver.status);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enhanced Status Card with Hero Animation
              Hero(
                tag: 'driver_status_card',
                child: Material(
                  color: Colors.transparent,
                  child: Card(
                    elevation: 8,
                    shadowColor: statusColor.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          colors: [
                            statusColor.withValues(alpha: 0.15),
                            statusColor.withValues(alpha: 0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            // Animated Icon with Glow Effect
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: statusColor.withValues(alpha: 0.2),
                                boxShadow: [
                                  BoxShadow(
                                    color: statusColor.withValues(alpha: 0.4),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Icon(
                                statusIcon,
                                size: 56,
                                color: statusColor,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Application Status',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Colors.grey[600],
                                    letterSpacing: 0.5,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.driver.status.displayName.toUpperCase(),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildStatusMessage(context),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Driver Details Section with Enhanced Cards
              _buildSectionTitle(context, 'Personal Information', Icons.person),
              const SizedBox(height: 16),
              _buildInfoCard(
                context,
                children: [
                  _buildDetailItem(
                      'Full Name', widget.driver.fullName, Icons.badge),
                  const Divider(height: 24),
                  _buildDetailItem(
                      'Email', widget.driver.email, Icons.email_outlined),
                  const Divider(height: 24),
                  _buildDetailItem(
                      'Phone', widget.driver.phone, Icons.phone_outlined),
                  const Divider(height: 24),
                  _buildDetailItem('License Number',
                      widget.driver.licenseNumber, Icons.card_membership),
                ],
              ),
              const SizedBox(height: 24),

              _buildSectionTitle(
                  context, 'Vehicle Information', Icons.directions_car),
              const SizedBox(height: 16),
              _buildInfoCard(
                context,
                children: [
                  _buildDetailItem(
                    'Vehicle Type',
                    widget.driver.vehicleInfo.type.displayName,
                    _getVehicleIcon(widget.driver.vehicleInfo.type),
                  ),
                  const Divider(height: 24),
                  _buildDetailItem(
                    'Make & Model',
                    '${widget.driver.vehicleInfo.make} ${widget.driver.vehicleInfo.model}',
                    Icons.car_repair,
                  ),
                  const Divider(height: 24),
                  _buildDetailItem(
                    'Year',
                    widget.driver.vehicleInfo.year.toString(),
                    Icons.calendar_today,
                  ),
                  const Divider(height: 24),
                  _buildDetailItem(
                    'Color',
                    widget.driver.vehicleInfo.color,
                    Icons.palette_outlined,
                  ),
                  const Divider(height: 24),
                  _buildDetailItem(
                    'License Plate',
                    widget.driver.vehicleInfo.plate,
                    Icons.pin_outlined,
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Action Buttons based on status
              ..._buildActionButtons(context),

              const SizedBox(height: 16),

              // Delete Application Button (not shown for suspended)
              if (widget.driver.status != DriverStatus.suspended)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete Application'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 32),
            ],
          ),
        ),
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
    switch (widget.driver.status) {
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
            if (widget.driver.rejectionReason != null) ...[
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
                      widget.driver.rejectionReason!,
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
            if (widget.driver.suspensionReason != null) ...[
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
                    Text(widget.driver.suspensionReason!),
                    if (widget.driver.suspensionExpiresAt != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Suspension ends: ${_formatDate(widget.driver.suspensionExpiresAt!)}',
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

  Widget _buildSectionTitle(
          BuildContext context, String title, IconData icon) =>
      Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      );

  Widget _buildInfoCard(BuildContext context,
          {required List<Widget> children}) =>
      Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      );

  List<Widget> _buildActionButtons(BuildContext context) {
    switch (widget.driver.status) {
      case DriverStatus.approved:
        return [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => context.go(RoutePaths.driverHome),
              icon: const Icon(Icons.dashboard_rounded, size: 24),
              label: const Text(
                'Go to Driver Dashboard',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: Colors.green.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ];
      case DriverStatus.rejected:
        return [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => context.go(RoutePaths.driverOnboarding),
              icon: const Icon(Icons.refresh_rounded, size: 24),
              label: const Text(
                'Submit New Application',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: Colors.blue.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ];
      case DriverStatus.suspended:
        return [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => context.go(RoutePaths.support),
              icon: const Icon(Icons.support_agent_rounded, size: 24),
              label: const Text(
                'Contact Support Team',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[700],
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: Colors.grey.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ];
      default:
        return [];
    }
  }

  Widget _buildDetailItem(String label, String value, IconData icon) => Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  IconData _getVehicleIcon(VehicleType type) {
    switch (type) {
      case VehicleType.motorcycle:
        return Icons.two_wheeler;
      case VehicleType.bicycle:
        return Icons.pedal_bike;
      case VehicleType.car:
        return Icons.directions_car;
      case VehicleType.van:
        return Icons.local_shipping;
    }
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
}
