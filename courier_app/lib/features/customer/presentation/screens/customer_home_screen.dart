import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/route_names.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../orders/presentation/blocs/order/order_bloc.dart';
import '../../../orders/presentation/blocs/order/order_event.dart';
import '../../../orders/presentation/blocs/order/order_state.dart';
import '../../../orders/presentation/widgets/order_card.dart';
import '../../../../core/widgets/common/connectivity_banner.dart';
import '../../../../core/widgets/common/sync_status_indicator.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const _HomeTab(),
    const _OrdersTab(),
    const _ProfileTab(),
  ];

  Future<void> _handleLogout(BuildContext context) async {
    final authRepository = GetIt.instance<AuthRepository>();

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    // Perform logout
    final result = await authRepository.logout();

    // Close loading indicator
    if (context.mounted) {
      Navigator.of(context).pop();
    }

    // Handle logout result
    result.fold(
      (failure) {
        // Show error message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Logout failed: ${failure.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      (success) {
        // Navigate to login screen
        if (context.mounted) {
          context.go(RoutePaths.login);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Customer Home'),
          actions: [
            const SyncStatusIndicator(),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => _handleLogout(context),
            ),
          ],
        ),
        body: Column(
          children: [
            const ConnectivityBanner(),
            Expanded(
              child: _screens[_currentIndex],
            ),
          ],
        ),
        floatingActionButton: _currentIndex == 1
            ? FloatingActionButton.extended(
                onPressed: () => context.push('/customer/home/orders/create'),
                icon: const Icon(Icons.add),
                label: const Text('New Order'),
              )
            : null,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'Orders',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      );
}

// Home Tab
class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.delivery_dining, size: 100, color: Colors.blue),
            const SizedBox(height: 24),
            const Text(
              'Welcome to Courier!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Fast and reliable delivery at your fingertips',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.push('/customer/home/orders/create'),
              icon: const Icon(Icons.add),
              label: const Text('Create Order'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      );
}

// Orders Tab
class _OrdersTab extends StatefulWidget {
  const _OrdersTab();

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> {
  late final OrderBloc _orderBloc;

  @override
  void initState() {
    super.initState();
    _orderBloc = GetIt.instance<OrderBloc>();
    _loadOrders();
  }

  @override
  void dispose() {
    _orderBloc.close();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    final authRepository = GetIt.instance<AuthRepository>();
    final userResult = await authRepository.getCurrentUser();

    userResult.fold(
      (failure) {
        // User not found, show error
      },
      (user) {
        // Load orders for this user
        _orderBloc.add(LoadUserOrders(user.id.value));
      },
    );
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
        value: _orderBloc,
        child: BlocBuilder<OrderBloc, OrderState>(
          builder: (context, state) {
            if (state is OrderLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is OrdersLoaded || state is OrdersWatching) {
              final orders = state is OrdersLoaded
                  ? state.orders
                  : (state as OrdersWatching).orders;

              if (orders.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined,
                          size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No orders yet',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create your first order to get started',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[500],
                            ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () =>
                            context.push('/customer/home/orders/create'),
                        icon: const Icon(Icons.add),
                        label: const Text('Create Order'),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: _loadOrders,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return OrderCard(
                      order: order,
                      onTap: () => context.push(
                        '/customer/home/orders/${order.id}/track',
                      ),
                    );
                  },
                ),
              );
            }

            if (state is OrderError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 80, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading orders',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _loadOrders,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No orders yet',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first order to get started',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[500],
                        ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () =>
                        context.push('/customer/home/orders/create'),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Order'),
                  ),
                ],
              ),
            );
          },
        ),
      );
}

// Profile Tab
class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 16),
          const CircleAvatar(
            radius: 50,
            child: Icon(Icons.person, size: 50),
          ),
          const SizedBox(height: 16),
          const Text(
            'Customer Profile',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Personal Information'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Navigate to personal info
            },
          ),
          ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: const Text('Delivery Addresses'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/customer/home/addresses'),
          ),
          ListTile(
            leading: const Icon(Icons.payment_outlined),
            title: const Text('Payment Methods'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/customer/home/payment'),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/customer/home/notifications'),
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings'),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & Support'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/support'),
          ),
        ],
      );
}
