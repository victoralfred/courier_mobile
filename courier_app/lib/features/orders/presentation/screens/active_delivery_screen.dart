import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:delivery_app/features/orders/domain/entities/order.dart';
import 'package:delivery_app/features/orders/domain/value_objects/order_status.dart';
import 'package:delivery_app/features/orders/presentation/blocs/order/order_bloc.dart';
import 'package:delivery_app/features/orders/presentation/blocs/order/order_event.dart';
import 'package:delivery_app/features/orders/presentation/blocs/order/order_state.dart';

/// Screen for driver to manage active delivery
class ActiveDeliveryScreen extends StatefulWidget {
  final String orderId;
  final String driverId;

  const ActiveDeliveryScreen({
    super.key,
    required this.orderId,
    required this.driverId,
  });

  @override
  State<ActiveDeliveryScreen> createState() => _ActiveDeliveryScreenState();
}

class _ActiveDeliveryScreenState extends State<ActiveDeliveryScreen> {
  @override
  void initState() {
    super.initState();
    // Watch order for real-time updates
    context.read<OrderBloc>().add(WatchOrder(widget.orderId));
  }

  void _updateStatus(Order order, OrderStatus newStatus) {
    final now = DateTime.now();

    context.read<OrderBloc>().add(
          UpdateOrderStatus(
            orderId: order.id,
            status: newStatus,
            pickupStartedAt: newStatus == OrderStatus.assigned
                ? now
                : order.pickupStartedAt,
            pickupCompletedAt: newStatus == OrderStatus.pickup
                ? now
                : order.pickupCompletedAt,
            completedAt:
                newStatus == OrderStatus.completed ? now : order.completedAt,
          ),
        );
  }

  String _getNextActionLabel(OrderStatus currentStatus) {
    switch (currentStatus) {
      case OrderStatus.pending:
      case OrderStatus.assigned:
        return 'Start Pickup';
      case OrderStatus.pickup:
        return 'Start Delivery';
      case OrderStatus.inTransit:
        return 'Complete Delivery';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  OrderStatus? _getNextStatus(OrderStatus currentStatus) {
    switch (currentStatus) {
      case OrderStatus.pending:
      case OrderStatus.assigned:
        return OrderStatus.pickup;
      case OrderStatus.pickup:
        return OrderStatus.inTransit;
      case OrderStatus.inTransit:
        return OrderStatus.completed;
      case OrderStatus.completed:
      case OrderStatus.cancelled:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Active Delivery'),
          elevation: 0,
        ),
        body: BlocConsumer<OrderBloc, OrderState>(
          listener: (context, state) {
            if (state is OrderUpdated) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Status updated successfully'),
                  backgroundColor: Colors.green,
                ),
              );

              // If completed, navigate back
              if (state.order.status == OrderStatus.completed) {
                Future.delayed(const Duration(seconds: 2), () {
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                });
              }
            } else if (state is OrderError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: ${state.message}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is OrderLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            Order? order;
            if (state is OrderWatching) {
              order = state.order;
            } else if (state is OrderLoaded) {
              order = state.order;
            } else if (state is OrderUpdated) {
              order = state.order;
            }

            if (order == null) {
              return const Center(
                child: Text('Order not found'),
              );
            }

            final nextStatus = _getNextStatus(order.status);

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status Progress
                  _buildStatusProgress(order.status),

                  // Map Placeholder
                  Container(
                    height: 300,
                    color: Colors.grey[200],
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.map_outlined,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Map View',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: Colors.grey[600],
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Integrate Google Maps or similar',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[500],
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Order Info
                        _buildSectionTitle('Order Details'),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          Icons.category_outlined,
                          'Item',
                          order.item.description,
                        ),
                        _buildInfoRow(
                          Icons.inventory_2_outlined,
                          'Size',
                          order.item.size.name,
                        ),
                        _buildInfoRow(
                          Icons.scale_outlined,
                          'Weight',
                          '${order.item.weight.toStringAsFixed(1)} kg',
                        ),
                        _buildInfoRow(
                          Icons.attach_money,
                          'Price',
                          '₦${order.price.amount.toStringAsFixed(2)}',
                        ),
                        const SizedBox(height: 24),

                        // Pickup Location
                        _buildSectionTitle('Pickup Location'),
                        const SizedBox(height: 12),
                        _buildLocationCard(
                          order.pickupLocation.address,
                          '${order.pickupLocation.city}, ${order.pickupLocation.state}',
                          Colors.green,
                        ),
                        const SizedBox(height: 16),

                        // Dropoff Location
                        _buildSectionTitle('Dropoff Location'),
                        const SizedBox(height: 12),
                        _buildLocationCard(
                          order.dropoffLocation.address,
                          '${order.dropoffLocation.city}, ${order.dropoffLocation.state}',
                          Colors.red,
                        ),
                        const SizedBox(height: 32),

                        // Action Button
                        if (nextStatus != null)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () =>
                                  _updateStatus(order!, nextStatus),
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: _getStatusColor(nextStatus),
                              ),
                              child: Text(
                                _getNextActionLabel(order.status),
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          )
                        else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Text(
                                'Delivery Completed',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

  Widget _buildStatusProgress(OrderStatus currentStatus) {
    final statuses = [
      OrderStatus.assigned,
      OrderStatus.pickup,
      OrderStatus.inTransit,
      OrderStatus.completed,
    ];

    final currentIndex = statuses.indexOf(currentStatus);

    return Container(
      padding: const EdgeInsets.all(24),
      color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
      child: Column(
        children: [
          Row(
            children: List.generate(statuses.length * 2 - 1, (index) {
              if (index.isEven) {
                final statusIndex = index ~/ 2;
                final status = statuses[statusIndex];
                final isActive = statusIndex <= currentIndex;

                return _buildStatusCircle(
                  _getStatusLabel(status),
                  isActive,
                );
              } else {
                final isActive = (index ~/ 2) < currentIndex;
                return Expanded(
                  child: Container(
                    height: 2,
                    color: isActive
                        ? Theme.of(context).primaryColor
                        : Colors.grey[300],
                  ),
                );
              }
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCircle(String label, bool isActive) => Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color:
                  isActive ? Theme.of(context).primaryColor : Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: Icon(
              isActive ? Icons.check : Icons.circle,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 70,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color:
                        isActive ? Theme.of(context).primaryColor : Colors.grey,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
            ),
          ),
        ],
      );

  Widget _buildSectionTitle(String title) => Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      );

  Widget _buildInfoRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey[600]),
            const SizedBox(width: 12),
            SizedBox(
              width: 80,
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
          ],
        ),
      );

  Widget _buildLocationCard(String address, String cityState, Color color) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
          color: color.withValues(alpha: 0.05),
        ),
        child: Row(
          children: [
            Icon(Icons.location_on, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    address,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cityState,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.assigned:
        return Colors.blue;
      case OrderStatus.pickup:
        return Colors.purple;
      case OrderStatus.inTransit:
        return Colors.indigo;
      case OrderStatus.completed:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }

  String _getStatusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.assigned:
        return 'Assigned';
      case OrderStatus.pickup:
        return 'Picking Up';
      case OrderStatus.inTransit:
        return 'In Transit';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }
}
