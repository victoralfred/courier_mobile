import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/registration_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/customer/presentation/screens/customer_home_screen.dart';
import '../../features/driver/presentation/screens/driver_home_screen.dart';
import '../../features/driver/onboarding/presentation/screens/driver_onboarding_screen.dart';
import 'route_guards.dart';
import 'route_names.dart';
import 'splash_screen.dart';

class AppRouter {
  final AuthRepository authRepository;
  late final AuthGuard authGuard;
  late final RoleGuard roleGuard;
  late final GoRouter router;

  AppRouter({required this.authRepository}) {
    authGuard = AuthGuard(authRepository: authRepository);
    roleGuard = RoleGuard(authRepository: authRepository);

    router = GoRouter(
      initialLocation: RoutePaths.splash,
      debugLogDiagnostics: true,
      routes: [
        // Splash Screen
        GoRoute(
          path: RoutePaths.splash,
          name: RouteNames.splash,
          builder: (context, state) => const SplashScreen(),
        ),

        // Auth Routes
        GoRoute(
          path: RoutePaths.login,
          name: RouteNames.login,
          builder: (context, state) {
            final redirect = state.uri.queryParameters['redirect'];
            return LoginScreen(redirectPath: redirect);
          },
          redirect: authGuard.redirectIfAuthenticated,
        ),
        GoRoute(
          path: RoutePaths.register,
          name: RouteNames.register,
          builder: (context, state) => const RegistrationScreen(),
          redirect: authGuard.redirectIfAuthenticated,
        ),
        GoRoute(
          path: RoutePaths.forgotPassword,
          name: RouteNames.forgotPassword,
          builder: (context, state) => const ForgotPasswordScreen(),
          redirect: authGuard.redirectIfAuthenticated,
        ),

        // Customer Routes
        GoRoute(
          path: RoutePaths.customerHome,
          name: RouteNames.customerHome,
          builder: (context, state) => const CustomerHomeScreen(),
          redirect: roleGuard.requireCustomerRole,
          routes: [
            GoRoute(
              path: 'profile',
              name: RouteNames.customerProfile,
              builder: (context, state) => const Scaffold(
                body: Center(child: Text('Customer Profile')),
              ),
            ),
            GoRoute(
              path: 'orders',
              name: RouteNames.customerOrders,
              builder: (context, state) => const Scaffold(
                body: Center(child: Text('Customer Orders')),
              ),
              routes: [
                GoRoute(
                  path: 'create',
                  name: RouteNames.customerCreateOrder,
                  builder: (context, state) => const Scaffold(
                    body: Center(child: Text('Create Order')),
                  ),
                ),
                GoRoute(
                  path: ':orderId',
                  name: RouteNames.customerOrderDetails,
                  builder: (context, state) {
                    final orderId = state.pathParameters['orderId']!;
                    return Scaffold(
                      body: Center(child: Text('Order Details: $orderId')),
                    );
                  },
                  routes: [
                    GoRoute(
                      path: 'track',
                      name: RouteNames.customerTrackOrder,
                      builder: (context, state) {
                        final orderId = state.pathParameters['orderId']!;
                        return Scaffold(
                          body: Center(child: Text('Track Order: $orderId')),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            GoRoute(
              path: 'payment',
              name: RouteNames.customerPayment,
              builder: (context, state) => const Scaffold(
                body: Center(child: Text('Payment Methods')),
              ),
            ),
            GoRoute(
              path: 'addresses',
              name: RouteNames.customerAddresses,
              builder: (context, state) => const Scaffold(
                body: Center(child: Text('Delivery Addresses')),
              ),
            ),
            GoRoute(
              path: 'notifications',
              name: RouteNames.customerNotifications,
              builder: (context, state) => const Scaffold(
                body: Center(child: Text('Notifications')),
              ),
            ),
          ],
        ),

        // Driver Routes
        GoRoute(
          path: RoutePaths.driverHome,
          name: RouteNames.driverHome,
          builder: (context, state) => const DriverHomeScreen(),
          redirect: roleGuard.requireDriverRole,
          routes: [
            GoRoute(
              path: 'profile',
              name: RouteNames.driverProfile,
              builder: (context, state) => const Scaffold(
                body: Center(child: Text('Driver Profile')),
              ),
            ),
            GoRoute(
              path: 'deliveries',
              name: RouteNames.driverDeliveries,
              builder: (context, state) => const Scaffold(
                body: Center(child: Text('Driver Deliveries')),
              ),
              routes: [
                GoRoute(
                  path: ':deliveryId',
                  name: RouteNames.driverDeliveryDetails,
                  builder: (context, state) {
                    final deliveryId = state.pathParameters['deliveryId']!;
                    return Scaffold(
                      body:
                          Center(child: Text('Delivery Details: $deliveryId')),
                    );
                  },
                ),
              ],
            ),
            GoRoute(
              path: 'earnings',
              name: RouteNames.driverEarnings,
              builder: (context, state) => const Scaffold(
                body: Center(child: Text('Driver Earnings')),
              ),
            ),
            GoRoute(
              path: 'vehicle',
              name: RouteNames.driverVehicle,
              builder: (context, state) => const Scaffold(
                body: Center(child: Text('Vehicle Information')),
              ),
            ),
            GoRoute(
              path: 'documents',
              name: RouteNames.driverDocuments,
              builder: (context, state) => const Scaffold(
                body: Center(child: Text('Driver Documents')),
              ),
            ),
            GoRoute(
              path: 'notifications',
              name: RouteNames.driverNotifications,
              builder: (context, state) => const Scaffold(
                body: Center(child: Text('Driver Notifications')),
              ),
            ),
          ],
        ),
        GoRoute(
          path: RoutePaths.driverOnboarding,
          name: RouteNames.driverOnboarding,
          builder: (context, state) => const DriverOnboardingScreen(),
          redirect: roleGuard.requireDriverRole,
        ),
        GoRoute(
          path: '/driver/navigation/:deliveryId',
          name: RouteNames.driverNavigation,
          builder: (context, state) {
            final deliveryId = state.pathParameters['deliveryId']!;
            return Scaffold(
              body: Center(child: Text('Navigation for: $deliveryId')),
            );
          },
          redirect: roleGuard.requireDriverRole,
        ),

        // Common Routes
        GoRoute(
          path: RoutePaths.settings,
          name: RouteNames.settings,
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Settings')),
          ),
          redirect: authGuard.redirectIfNotAuthenticated,
        ),
        GoRoute(
          path: RoutePaths.support,
          name: RouteNames.support,
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Support')),
          ),
        ),
        GoRoute(
          path: RoutePaths.about,
          name: RouteNames.about,
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('About')),
          ),
        ),
        GoRoute(
          path: RoutePaths.termsAndConditions,
          name: RouteNames.termsAndConditions,
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Terms and Conditions')),
          ),
        ),
        GoRoute(
          path: RoutePaths.privacyPolicy,
          name: RouteNames.privacyPolicy,
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Privacy Policy')),
          ),
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Page not found',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                state.error?.toString() ?? 'Unknown error',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go(RoutePaths.login),
                child: const Text('Go to Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}