import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:delivery_app/features/orders/domain/entities/order.dart';
import 'package:delivery_app/features/orders/presentation/blocs/order/order_bloc.dart';
import 'package:delivery_app/features/orders/presentation/blocs/order/order_event.dart';
import 'package:delivery_app/features/orders/presentation/blocs/order/order_state.dart';
import 'package:delivery_app/features/orders/presentation/widgets/order_card.dart';

/// Screen for drivers to view and accept available orders
class AvailableOrdersScreen extends StatefulWidget {
  final String driverId;

  const AvailableOrdersScreen({
    super.key,
    required this.driverId,
  });

  @override
  State<AvailableOrdersScreen> createState() => _AvailableOrdersScreenState();
}

class _AvailableOrdersScreenState extends State<AvailableOrdersScreen> {
  @override
  void initState() {
    super.initState();
    // Load pending orders (available for drivers to accept)
    context.read<OrderBloc>().add(const LoadUserOrders('all'));
  }

  void _acceptOrder(Order order) {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Order'),
        content: Text(
          'Do you want to accept this delivery from ${order.pickupLocation.city} to ${order.dropoffLocation.city}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Assign driver to order
              context.read<OrderBloc>().add(
                    AssignDriver(
                      orderId: order.id,
                      driverId: widget.driverId,
                    ),
                  );
              Navigator.pop(context);
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Available Orders'),
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                context.read<OrderBloc>().add(const LoadUserOrders('all'));
              },
            ),
          ],
        ),
        body: BlocConsumer<OrderBloc, OrderState>(
          listener: (context, state) {
            if (state is OrderUpdated) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Order accepted successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
              // Reload available orders
              context.read<OrderBloc>().add(const LoadUserOrders('all'));
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

            if (state is OrdersLoaded || state is OrdersWatching) {
              final orders = state is OrdersLoaded
                  ? state.orders
                  : (state as OrdersWatching).orders;

              // Filter only pending orders (not assigned to any driver)
              final availableOrders =
                  orders.where((order) => order.driverId == null).toList();

              if (availableOrders.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No available orders',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Check back later for new deliveries',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[500],
                            ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  context.read<OrderBloc>().add(const LoadUserOrders('all'));
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: availableOrders.length,
                  itemBuilder: (context, index) {
                    final order = availableOrders[index];
                    return OrderCard(
                      order: order,
                      onTap: () => _showOrderDetails(order),
                      trailing: ElevatedButton(
                        onPressed: () => _acceptOrder(order),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: const Text('Accept'),
                      ),
                    );
                  },
                ),
              );
            }

            return const Center(
              child: Text('Something went wrong'),
            );
          },
        ),
      );

  void _showOrderDetails(Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Order Details',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 32),
              _buildDetailRow('Order ID', order.id),
              _buildDetailRow('Status', order.status.name.toUpperCase()),
              const SizedBox(height: 24),
              Text(
                'Pickup Location',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(order.pickupLocation.address),
              Text(
                  '${order.pickupLocation.city}, ${order.pickupLocation.state}'),
              const SizedBox(height: 24),
              Text(
                'Dropoff Location',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(order.dropoffLocation.address),
              Text(
                  '${order.dropoffLocation.city}, ${order.dropoffLocation.state}'),
              const SizedBox(height: 24),
              Text(
                'Item Details',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              _buildDetailRow('Category', order.item.category),
              _buildDetailRow('Description', order.item.description),
              _buildDetailRow('Size', order.item.size.name),
              _buildDetailRow('Weight',
                  '${order.item.weight.toStringAsFixed(1)} kg'),
              const SizedBox(height: 24),
              _buildDetailRow(
                'Price',
                '₦${order.price.amount.toStringAsFixed(2)}',
                valueStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _acceptOrder(order);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Accept Order',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    TextStyle? valueStyle,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
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
}
