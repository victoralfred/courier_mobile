import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/domain/entities/user_role.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import 'route_names.dart';

/// Guard to check if user is authenticated
class AuthGuard {
  final AuthRepository authRepository;

  AuthGuard({required this.authRepository});

  /// Redirect logic for authenticated routes
  Future<String?> redirectIfNotAuthenticated(
    BuildContext context,
    GoRouterState state,
  ) async {
    final isAuthenticated = await authRepository.isAuthenticated();

    if (!isAuthenticated) {
      // Save the intended destination
      final queryParams = <String, String>{
        'redirect': state.uri.toString(),
      };
      return Uri(
        path: RoutePaths.login,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      ).toString();
    }

    return null; // No redirect needed
  }

  /// Redirect logic for auth screens (login, register)
  Future<String?> redirectIfAuthenticated(
    BuildContext context,
    GoRouterState state,
  ) async {
    final isAuthenticated = await authRepository.isAuthenticated();

    if (isAuthenticated) {
      // Get user to determine their role
      final userResult = await authRepository.getCurrentUser();

      return userResult.fold(
        (failure) => RoutePaths.login,
        (user) {
          // Redirect based on role
          switch (user.role.type) {
            case UserRoleType.customer:
              return RoutePaths.customerHome;
            case UserRoleType.driver:
              // Check if driver has completed onboarding
              if (user.role.permissions.contains('driver.verified')) {
                return RoutePaths.driverHome;
              } else {
                return RoutePaths.driverOnboarding;
              }
          }
        },
      );
    }

    return null; // No redirect needed
  }
}

/// Guard to check role-based access
class RoleGuard {
  final AuthRepository authRepository;

  RoleGuard({required this.authRepository});

  /// Check if user has customer role
  Future<String?> requireCustomerRole(
    BuildContext context,
    GoRouterState state,
  ) async {
    final isAuthenticated = await authRepository.isAuthenticated();

    if (!isAuthenticated) {
      return RoutePaths.login;
    }

    final userResult = await authRepository.getCurrentUser();

    return userResult.fold(
      (failure) => RoutePaths.login,
      (user) {
        if (user.role.type != UserRoleType.customer) {
          // Redirect to appropriate home based on actual role
          switch (user.role.type) {
            case UserRoleType.driver:
              return user.role.permissions.contains('driver.verified')
                  ? RoutePaths.driverHome
                  : RoutePaths.driverOnboarding;
            default:
              return RoutePaths.login;
          }
        }
        return null; // User has customer role
      },
    );
  }

  /// Check if user has driver role
  Future<String?> requireDriverRole(
    BuildContext context,
    GoRouterState state,
  ) async {
    final isAuthenticated = await authRepository.isAuthenticated();

    if (!isAuthenticated) {
      return RoutePaths.login;
    }

    final userResult = await authRepository.getCurrentUser();

    return userResult.fold(
      (failure) => RoutePaths.login,
      (user) {
        if (user.role.type != UserRoleType.driver) {
          // Redirect to appropriate home based on actual role
          switch (user.role.type) {
            case UserRoleType.customer:
              return RoutePaths.customerHome;
            default:
              return RoutePaths.login;
          }
        }

        // Check if driver needs onboarding
        if (state.uri.path != RoutePaths.driverOnboarding &&
            !user.role.permissions.contains('driver.verified')) {
          return RoutePaths.driverOnboarding;
        }

        return null; // User has driver role
      },
    );
  }
}
