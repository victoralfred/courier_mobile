import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/domain/entities/user_role.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/drivers/domain/repositories/driver_repository.dart';
import '../services/app_logger.dart';
import 'route_names.dart';

/// Guard to check if user is authenticated
class AuthGuard {
  static final _logger = AppLogger('Routing');

  final AuthRepository authRepository;
  final DriverRepository driverRepository;

  AuthGuard({
    required this.authRepository,
    required this.driverRepository,
  });

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

      return await userResult.fold(
        (failure) async => RoutePaths.login,
        (user) async {
          // Redirect based on role
          switch (user.role.type) {
            case UserRoleType.customer:
            case UserRoleType.admin: // Admin users go to customer home
              return RoutePaths.customerHome;
            case UserRoleType.driver:
              // Check driver status from database
              final driverResult =
                  await driverRepository.getDriverByUserId(user.id.value);

              return driverResult.fold(
                (failure) => RoutePaths.driverOnboarding,
                (driver) {
                  // Redirect based on driver status
                  if (driver.status.name == 'approved') {
                    return RoutePaths.driverHome;
                  } else {
                    return RoutePaths.driverStatus;
                  }
                },
              );
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
  final DriverRepository driverRepository;

  RoleGuard({
    required this.authRepository,
    required this.driverRepository,
  });

  /// Check if user has customer role
  Future<String?> requireCustomerRole(
    BuildContext context,
    GoRouterState state,
  ) async {
    _logger.debug('Checking customer role requirement', metadata: {
      'path': state.uri.path,
    });
    final isAuthenticated = await authRepository.isAuthenticated();
    _logger.debug('Authentication status checked', metadata: {
      'isAuthenticated': isAuthenticated,
    });

    if (!isAuthenticated) {
      _logger.info('User not authenticated, redirecting to login');
      return RoutePaths.login;
    }

    final userResult = await authRepository.getCurrentUser();

    return await userResult.fold(
      (failure) async {
        _logger.error('Failed to get current user', metadata: {
          'error': failure.message,
        });
        return RoutePaths.login;
      },
      (user) async {
        _logger.debug('User role retrieved', metadata: {
          'role': user.role.type,
        });
        // Allow both customer and admin roles
        if (user.role.type != UserRoleType.customer &&
            user.role.type != UserRoleType.admin) {
          // Redirect to appropriate home based on actual role
          switch (user.role.type) {
            case UserRoleType.driver:
              // Check if driver has completed onboarding
              final driverResult =
                  await driverRepository.getDriverByUserId(user.id.value);
              final hasDriverRecord = driverResult.isRight();
              return hasDriverRecord
                  ? RoutePaths.driverStatus
                  : RoutePaths.driverOnboarding;
            default:
              return RoutePaths.login;
          }
        }
        _logger.debug('User has correct role, allowing navigation');
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
      (user) async {
        if (user.role.type != UserRoleType.driver) {
          // Redirect to appropriate home based on actual role
          switch (user.role.type) {
            case UserRoleType.customer:
              return RoutePaths.customerHome;
            default:
              return RoutePaths.login;
          }
        }

        // Check if driver has completed onboarding by checking for driver record
        if (state.uri.path != RoutePaths.driverOnboarding) {
          _logger.debug('Checking for driver record', metadata: {
            'path': state.uri.path,
          });
          final driverResult =
              await driverRepository.getDriverByUserId(user.id.value);

          // If no driver record exists, redirect to onboarding
          return driverResult.fold(
            (failure) {
              _logger.info('No driver record found, redirecting to onboarding');
              return RoutePaths.driverOnboarding;
            },
            (driver) {
              _logger.debug('Driver record found', metadata: {
                'status': driver.status.name,
              });

              // Redirect based on status and current path
              if (state.uri.path == RoutePaths.driverStatus) {
                // Allow access to status screen for non-approved drivers
                if (driver.status.name != 'approved') {
                  _logger.debug('Driver not approved, allowing status screen access');
                  return null;
                }
                // Redirect approved drivers to home
                _logger.info('Driver approved, redirecting to home');
                return RoutePaths.driverHome;
              } else if (state.uri.path == RoutePaths.driverHome) {
                // Redirect non-approved drivers to status screen
                if (driver.status.name != 'approved') {
                  _logger.info('Driver not approved, redirecting to status screen');
                  return RoutePaths.driverStatus;
                }
                // Allow approved drivers to access home
                _logger.debug('Driver approved, allowing home access');
                return null;
              }

              // For other paths, allow navigation if driver has a record
              return null;
            },
          );
        }

        return null; // User has driver role and driver record
      },
    );
  }
}
