import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/entities/user_role.dart';
import '../../features/drivers/domain/repositories/driver_repository.dart';
import '../constants/app_strings.dart';
import 'route_names.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _checkAuthAndNavigate();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _animationController.forward();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Wait for animation to complete
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final authRepository = context.read<AuthRepository>();
    final isAuthenticated = await authRepository.isAuthenticated();

    if (!mounted) return;

    if (isAuthenticated) {
      // Get user to determine role-based navigation
      final userResult = await authRepository.getCurrentUser();

      if (!mounted) return;

      userResult.fold(
        (failure) {
          // If we can't get user, go to login
          context.go(RoutePaths.login);
        },
        (user) async {
          // Navigate based on user role
          switch (user.role.type) {
            case UserRoleType.customer:
            case UserRoleType.admin: // Admin users go to customer home
              context.go(RoutePaths.customerHome);
              break;
            case UserRoleType.driver:
              // Check if driver has completed onboarding by checking database
              print('SplashScreen: User is a driver, checking for driver record...');
              final driverRepository = GetIt.instance<DriverRepository>();
              final driverResult =
                  await driverRepository.getDriverByUserId(user.id.value);

              if (!mounted) return;

              driverResult.fold(
                (failure) {
                  // No driver record - navigate to onboarding
                  print('SplashScreen: No driver record found - ${failure.message}');
                  print('SplashScreen: Navigating to onboarding...');
                  context.go(RoutePaths.driverOnboarding);
                },
                (driver) {
                  // Driver record exists - navigate based on status
                  print('SplashScreen: Driver record found - Status: ${driver.status.name}');

                  if (driver.status.name == 'approved') {
                    // Approved drivers go to home
                    print('SplashScreen: Navigating to driver home...');
                    context.go(RoutePaths.driverHome);
                  } else {
                    // Non-approved drivers go to status screen
                    print('SplashScreen: Navigating to status screen...');
                    context.go(RoutePaths.driverStatus);
                  }
                },
              );
              break;
          }
        },
      );
    } else {
      // Not authenticated, go to login
      context.go(RoutePaths.login);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Theme.of(context).primaryColor,
        body: Center(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) => FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Icon
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.local_shipping_rounded,
                        size: 60,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // App Name
                    const Text(
                      AppStrings.appName,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Tagline
                    Text(
                      AppStrings.appTagline,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.9),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Loading indicator
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
