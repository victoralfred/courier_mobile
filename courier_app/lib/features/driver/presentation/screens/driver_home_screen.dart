import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/route_names.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../../core/widgets/common/connectivity_banner.dart';
import '../../../../core/widgets/common/sync_status_indicator.dart';

class DriverHomeScreen extends StatelessWidget {
  const DriverHomeScreen({super.key});

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
          title: const Text('Driver Dashboard'),
          actions: [
            const SyncStatusIndicator(),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => _handleLogout(context),
            ),
          ],
        ),
        body: const Column(
          children: [
            ConnectivityBanner(),
            Expanded(
              child: Center(
                child: Text(
                  'Welcome Driver!',
                  style: TextStyle(fontSize: 24),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.local_shipping),
              label: 'Deliveries',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.attach_money),
              label: 'Earnings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      );
}
