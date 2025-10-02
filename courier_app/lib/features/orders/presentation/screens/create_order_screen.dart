import 'package:delivery_app/core/domain/value_objects/coordinate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:delivery_app/core/domain/value_objects/location.dart';
import 'package:delivery_app/core/domain/value_objects/money.dart';
import 'package:delivery_app/features/orders/domain/entities/order.dart';
import 'package:delivery_app/features/orders/domain/entities/order_item.dart';
import 'package:delivery_app/features/orders/domain/value_objects/order_status.dart';
import 'package:delivery_app/features/orders/domain/value_objects/package_size.dart';
import 'package:delivery_app/features/orders/presentation/blocs/order/order_bloc.dart';
import 'package:delivery_app/features/orders/presentation/blocs/order/order_event.dart';
import 'package:delivery_app/features/orders/presentation/blocs/order/order_state.dart';
import 'package:delivery_app/features/orders/presentation/widgets/location_picker.dart';

class CreateOrderScreen extends StatefulWidget {
  final String userId;

  const CreateOrderScreen({
    super.key,
    required this.userId,
  });

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  // Location data
  Location? _pickupLocation;
  Location? _dropoffLocation;

  // Item data
  String _selectedCategory = 'Documents';
  PackageSize _selectedSize = PackageSize.small;
  double _weight = 1.0; // kg

  // Price (will be calculated)
  double _estimatedPrice = 0.0;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _calculatePrice() {
    // Simple price calculation based on distance, size, and weight
    if (_pickupLocation != null && _dropoffLocation != null) {
      // Calculate distance (simplified - in real app use haversine formula)
      final distance = _calculateDistance(
        _pickupLocation!.coordinate,
        _dropoffLocation!.coordinate,
      );

      // Base price: 500 + (distance * 50) + (weight * 100) + size multiplier
      final double basePrice = 500.0;
      final double distancePrice = distance * 50;
      final double weightPrice = _weight * 100;
      final double sizeMultiplier = _getSizeMultiplier();

      _estimatedPrice =
          (basePrice + distancePrice + weightPrice) * sizeMultiplier;

      setState(() {});
    }
  }

  double _calculateDistance(Coordinate from, Coordinate to) {
    // Simplified distance calculation (use proper haversine in production)
    final latDiff = (to.latitude - from.latitude).abs();
    final lngDiff = (to.longitude - from.longitude).abs();
    return (latDiff + lngDiff) * 111; // Approximate km
  }

  double _getSizeMultiplier() {
    switch (_selectedSize) {
      case PackageSize.small:
        return 1.0;
      case PackageSize.medium:
        return 1.3;
      case PackageSize.large:
        return 1.6;
      case PackageSize.xlarge:
        return 2.0;
    }
  }

  void _submitOrder() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_pickupLocation == null || _dropoffLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both pickup and dropoff locations'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Create order
    final order = Order(
      id: const Uuid().v4(),
      userId: widget.userId,
      driverId: null,
      pickupLocation: _pickupLocation!,
      dropoffLocation: _dropoffLocation!,
      item: OrderItem(
        category: _selectedCategory,
        description: _descriptionController.text.trim(),
        weight: _weight,
        size: _selectedSize,
      ),
      price: Money(amount: _estimatedPrice),
      status: OrderStatus.pending,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Dispatch create order event
    context.read<OrderBloc>().add(CreateOrder(order));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Create Order'),
          elevation: 0,
        ),
        body: BlocListener<OrderBloc, OrderState>(
          listener: (context, state) {
            if (state is OrderCreated) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Order created successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
              context.pop(); // Go back to previous screen
            } else if (state is OrderError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: ${state.message}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: BlocBuilder<OrderBloc, OrderState>(
            builder: (context, state) {
              if (state is OrderLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Pickup Location
                      _buildSectionTitle('Pickup Location'),
                      LocationPicker(
                        label: 'Select pickup location',
                        location: _pickupLocation,
                        onLocationSelected: (location) {
                          setState(() {
                            _pickupLocation = location;
                            _calculatePrice();
                          });
                        },
                      ),
                      const SizedBox(height: 24),

                      // Dropoff Location
                      _buildSectionTitle('Dropoff Location'),
                      LocationPicker(
                        label: 'Select dropoff location',
                        location: _dropoffLocation,
                        onLocationSelected: (location) {
                          setState(() {
                            _dropoffLocation = location;
                            _calculatePrice();
                          });
                        },
                      ),
                      const SizedBox(height: 24),

                      // Item Details
                      _buildSectionTitle('Item Details'),
                      const SizedBox(height: 12),

                      // Category
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'Documents', child: Text('Documents')),
                          DropdownMenuItem(value: 'Food', child: Text('Food')),
                          DropdownMenuItem(
                              value: 'Electronics', child: Text('Electronics')),
                          DropdownMenuItem(
                              value: 'Clothing', child: Text('Clothing')),
                          DropdownMenuItem(
                              value: 'Furniture', child: Text('Furniture')),
                          DropdownMenuItem(
                              value: 'Other', child: Text('Other')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedCategory = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'Brief description of the item',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please provide a description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Size
                      DropdownButtonFormField<PackageSize>(
                        initialValue: _selectedSize,
                        decoration: const InputDecoration(
                          labelText: 'Size',
                          border: OutlineInputBorder(),
                        ),
                        items: PackageSize.values
                            .map((size) => DropdownMenuItem(
                                  value: size,
                                  child: Text(_getSizeLabel(size)),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedSize = value;
                              _calculatePrice();
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Weight
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Weight: ${_weight.toStringAsFixed(1)} kg',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _weight,
                        min: 0.5,
                        max: 50.0,
                        divisions: 99,
                        label: '${_weight.toStringAsFixed(1)} kg',
                        onChanged: (value) {
                          setState(() {
                            _weight = value;
                            _calculatePrice();
                          });
                        },
                      ),
                      const SizedBox(height: 24),

                      // Price Estimate
                      if (_estimatedPrice > 0) ...[
                        Card(
                          color:
                              Theme.of(context).primaryColor.withValues(alpha: 0.1),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Estimated Price:',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                Text(
                                  '₦${_estimatedPrice.toStringAsFixed(2)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: Theme.of(context).primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Submit Button
                      ElevatedButton(
                        onPressed: _submitOrder,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Create Order',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );

  Widget _buildSectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      );

  String _getSizeLabel(PackageSize size) {
    switch (size) {
      case PackageSize.small:
        return 'Small (< 30cm)';
      case PackageSize.medium:
        return 'Medium (30-60cm)';
      case PackageSize.large:
        return 'Large (60-100cm)';
      case PackageSize.xlarge:
        return 'Extra Large (> 100cm)';
    }
  }
}
