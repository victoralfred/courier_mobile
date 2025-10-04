import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:delivery_app/features/orders/domain/entities/order.dart';
import 'package:delivery_app/features/orders/domain/value_objects/order_status.dart';
import 'package:delivery_app/features/orders/presentation/blocs/order/order_bloc.dart';
import 'package:delivery_app/features/orders/presentation/blocs/order/order_event.dart';
import 'package:delivery_app/features/orders/presentation/blocs/order/order_state.dart';

/// Screen for customer to track their order in real-time
class OrderTrackingScreen extends StatefulWidget {
  final String orderId;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  @override
  void initState() {
    super.initState();
    // Watch order for real-time updates
    context.read<OrderBloc>().add(WatchOrder(widget.orderId));
  }

  void _cancelOrder(Order order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text(
          'Are you sure you want to cancel this order?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<OrderBloc>().add(CancelOrder(order.id));
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Track Order'),
          elevation: 0,
        ),
        body: BlocConsumer<OrderBloc, OrderState>(
          listener: (context, state) {
            if (state is OrderCancelled) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Order cancelled successfully'),
                  backgroundColor: Colors.orange,
                ),
              );
              Navigator.of(context).pop();
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
            }

            if (order == null) {
              return const Center(
                child: Text('Order not found'),
              );
            }

            final canCancel = order.status == OrderStatus.pending ||
                order.status == OrderStatus.assigned;

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status Header
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _getStatusColor(order.status),
                          _getStatusColor(order.status).withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _getStatusIcon(order.status),
                          size: 60,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _getStatusTitle(order.status),
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getStatusMessage(order.status),
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                        ),
                      ],
                    ),
                  ),

                  // Map Placeholder
                  Container(
                    height: 250,
                    color: Colors.grey[200],
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.map_outlined,
                                size: 60,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Live Tracking Map',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Integrate Google Maps or similar',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.grey[500],
                                    ),
                              ),
                            ],
                          ),
                        ),
                        if (order.driverId != null)
                          Positioned(
                            top: 16,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.local_shipping,
                                      size: 20, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Driver Assigned',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Timeline
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order Timeline',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 24),
                        _buildTimeline(order),
                        const SizedBox(height: 32),

                        // Order Details
                        Text(
                          'Order Details',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 16),
                        _buildDetailCard(order),
                        const SizedBox(height: 24),

                        // Cancel Button
                        if (canCancel)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => _cancelOrder(order!),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                side: const BorderSide(color: Colors.red),
                              ),
                              child: const Text(
                                'Cancel Order',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
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

  Widget _buildTimeline(Order order) {
    final events = [
      _TimelineEvent(
        'Order Placed',
        order.createdAt,
        Icons.shopping_bag,
        true,
      ),
      _TimelineEvent(
        'Order Assigned',
        order.pickupStartedAt,
        Icons.check_circle,
        order.status.index >= OrderStatus.assigned.index,
      ),
      _TimelineEvent(
        'Picked Up',
        order.pickupCompletedAt,
        Icons.inventory_2,
        order.status.index >= OrderStatus.pickup.index,
      ),
      _TimelineEvent(
        'In Transit',
        null,
        Icons.local_shipping,
        order.status.index >= OrderStatus.inTransit.index,
      ),
      _TimelineEvent(
        'Completed',
        order.completedAt,
        Icons.done_all,
        order.status == OrderStatus.completed,
      ),
    ];

    return Column(
      children: events.asMap().entries.map((entry) {
        final isLast = entry.key == events.length - 1;
        return _buildTimelineItem(entry.value, !isLast);
      }).toList(),
    );
  }

  Widget _buildTimelineItem(_TimelineEvent event, bool showLine) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: event.isCompleted
                      ? Theme.of(context).primaryColor
                      : Colors.grey[300],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  event.icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              if (showLine)
                Container(
                  width: 2,
                  height: 50,
                  color: event.isCompleted
                      ? Theme.of(context).primaryColor
                      : Colors.grey[300],
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: event.isCompleted ? Colors.black : Colors.grey,
                        ),
                  ),
                  if (event.timestamp != null)
                    Text(
                      _formatTimestamp(event.timestamp!),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                ],
              ),
            ),
          ),
        ],
      );

  Widget _buildDetailCard(Order order) => Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Order ID', order.id),
              const Divider(height: 24),
              _buildDetailRow('Item', order.item.description),
              _buildDetailRow('Category', order.item.category),
              _buildDetailRow('Size', order.item.size.name),
              _buildDetailRow(
                  'Weight', '${order.item.weight.toStringAsFixed(1)} kg'),
              const Divider(height: 24),
              _buildDetailRow('From', order.pickupLocation.address),
              _buildDetailRow('To', order.dropoffLocation.address),
              const Divider(height: 24),
              _buildDetailRow(
                'Price',
                '₦${order.price.amount.toStringAsFixed(2)}',
                valueStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
      );

  Widget _buildDetailRow(String label, String value, {TextStyle? valueStyle}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
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
                style: valueStyle ??
                    Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
              ),
            ),
          ],
        ),
      );

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

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

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.schedule;
      case OrderStatus.assigned:
        return Icons.check_circle;
      case OrderStatus.pickup:
        return Icons.inventory_2;
      case OrderStatus.inTransit:
        return Icons.local_shipping;
      case OrderStatus.completed:
        return Icons.done_all;
      case OrderStatus.cancelled:
        return Icons.cancel;
    }
  }

  String _getStatusTitle(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Order Pending';
      case OrderStatus.assigned:
        return 'Driver Assigned';
      case OrderStatus.pickup:
        return 'Picking Up';
      case OrderStatus.inTransit:
        return 'On The Way';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  String _getStatusMessage(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'We are finding a driver for your order';
      case OrderStatus.assigned:
        return 'Your driver is heading to pickup location';
      case OrderStatus.pickup:
        return 'Your package is being picked up';
      case OrderStatus.inTransit:
        return 'Your package is on the way';
      case OrderStatus.completed:
        return 'Your package has been delivered';
      case OrderStatus.cancelled:
        return 'This order was cancelled';
    }
  }
}

class _TimelineEvent {
  final String title;
  final DateTime? timestamp;
  final IconData icon;
  final bool isCompleted;

  _TimelineEvent(this.title, this.timestamp, this.icon, this.isCompleted);
}
