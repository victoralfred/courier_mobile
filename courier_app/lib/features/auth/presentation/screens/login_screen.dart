import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:delivery_app/core/network/connectivity_service.dart';
import 'package:delivery_app/core/routing/route_names.dart';
import 'package:delivery_app/features/auth/domain/entities/user_role.dart';
import 'package:delivery_app/features/auth/presentation/blocs/login/login_bloc.dart';
import 'package:delivery_app/features/auth/presentation/blocs/login/login_event.dart';
import 'package:delivery_app/features/auth/presentation/blocs/login/login_state.dart';
import 'package:delivery_app/features/drivers/domain/repositories/driver_repository.dart';

class LoginScreen extends StatelessWidget {
  final String? redirectPath;

  const LoginScreen({super.key, this.redirectPath});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: BlocConsumer<LoginBloc, LoginState>(
            listener: (context, state) {
              print('LoginScreen BlocListener: status=${state.status}, user=${state.user != null}');

              if (state.status == LoginStatus.failure &&
                  state.generalError != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.generalError!),
                    backgroundColor: Colors.red,
                  ),
                );
              } else if (state.status == LoginStatus.success &&
                  state.user != null) {
                print('LoginScreen: Login success! User role: ${state.user!.role.type}');
                // Handle redirect or navigate based on user role
                if (redirectPath != null && redirectPath!.isNotEmpty) {
                  print('LoginScreen: Navigating to redirect path: $redirectPath');
                  context.go(redirectPath!);
                } else {
                  // Navigate based on user role
                  switch (state.user!.role.type) {
                    case UserRoleType.customer:
                    case UserRoleType.admin: // Admin users go to customer home
                      print('LoginScreen: Navigating to customer home');
                      context.go(RoutePaths.customerHome);
                      break;
                    case UserRoleType.driver:
                      _handleDriverNavigation(context, state.user!.id.value);
                      break;
                  }
                }
              }
            },
            builder: (context, state) => SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 48),
                  _buildHeader(),
                  const SizedBox(height: 48),
                  _buildEmailField(context, state),
                  const SizedBox(height: 16),
                  _buildPasswordField(context, state),
                  const SizedBox(height: 24),
                  _buildLoginButton(context, state),
                  const SizedBox(height: 16),
                  _buildForgotPasswordLink(context),
                  const SizedBox(height: 32),
                  _buildDivider(),
                  const SizedBox(height: 24),
                  _buildSocialLoginButtons(context, state),
                  if (state.isBiometricAvailable) ...[
                    const SizedBox(height: 24),
                    _buildBiometricButton(context, state),
                  ],
                  const SizedBox(height: 32),
                  _buildSignUpLink(context),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _buildHeader() => Column(
        children: [
          Icon(
            Icons.local_shipping,
            size: 80,
            color: Colors.blue[700],
          ),
          const SizedBox(height: 16),
          const Text(
            AppStrings.loginTitle,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );

  Widget _buildEmailField(BuildContext context, LoginState state) => TextField(
        onChanged: (email) {
          context.read<LoginBloc>().add(LoginEmailChanged(email));
        },
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: AppStrings.emailLabel,
          errorText: state.emailError,
          prefixIcon: const Icon(Icons.email_outlined),
          border: const OutlineInputBorder(),
        ),
      );

  Widget _buildPasswordField(BuildContext context, LoginState state) =>
      TextField(
        onChanged: (password) {
          context.read<LoginBloc>().add(LoginPasswordChanged(password));
        },
        obscureText: !state.isPasswordVisible,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: AppStrings.passwordLabel,
          errorText: state.passwordError,
          prefixIcon: const Icon(Icons.lock_outlined),
          suffixIcon: IconButton(
            icon: Icon(
              state.isPasswordVisible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            onPressed: () {
              context
                  .read<LoginBloc>()
                  .add(const LoginPasswordVisibilityToggled());
            },
          ),
          border: const OutlineInputBorder(),
        ),
      );

  Widget _buildLoginButton(BuildContext context, LoginState state) => SizedBox(
        height: 48,
        child: ElevatedButton(
          onPressed: state.canSubmit && !state.isLoading
              ? () {
                  context.read<LoginBloc>().add(const LoginSubmitted());
                }
              : null,
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: state.isLoading
              ? const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                )
              : const Text(
                  AppStrings.loginButton,
                  style: TextStyle(fontSize: 16),
                ),
        ),
      );

  Widget _buildForgotPasswordLink(BuildContext context) => Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () {
            context.push(RoutePaths.forgotPassword);
          },
          child: const Text(AppStrings.forgotPassword),
        ),
      );

  Widget _buildDivider() => Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'OR',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      );

  Widget _buildSocialLoginButtons(BuildContext context, LoginState state) =>
      Column(
        children: [
          _buildOAuthButton(
            context: context,
            provider: OAuthProviderType.google,
            icon: Icons.g_mobiledata,
            label: AppStrings.loginWithGoogle,
            color: Colors.red,
            enabled: !state.isLoading,
          ),
          const SizedBox(height: 12),
          _buildOAuthButton(
            context: context,
            provider: OAuthProviderType.github,
            icon: Icons.code,
            label: AppStrings.loginWithGithub,
            color: Colors.black,
            enabled: !state.isLoading,
          ),
          const SizedBox(height: 12),
          _buildOAuthButton(
            context: context,
            provider: OAuthProviderType.microsoft,
            icon: Icons.window,
            label: AppStrings.loginWithMicrosoft,
            color: Colors.blue,
            enabled: !state.isLoading,
          ),
        ],
      );

  Widget _buildOAuthButton({
    required BuildContext context,
    required OAuthProviderType provider,
    required IconData icon,
    required String label,
    required Color color,
    required bool enabled,
  }) =>
      SizedBox(
        height: 48,
        child: OutlinedButton.icon(
          onPressed: enabled
              ? () {
                  context.read<LoginBloc>().add(LoginWithOAuth(provider));
                }
              : null,
          icon: Icon(icon, color: color),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );

  Widget _buildBiometricButton(BuildContext context, LoginState state) =>
      Center(
        child: IconButton(
          onPressed: !state.isLoading
              ? () {
                  context.read<LoginBloc>().add(const LoginWithBiometric());
                }
              : null,
          icon: const Icon(Icons.fingerprint),
          iconSize: 48,
          color: Colors.blue[700],
        ),
      );

  Widget _buildSignUpLink(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(AppStrings.signUpPrompt),
          TextButton(
            onPressed: () {
              context.push(RoutePaths.register);
            },
            child: const Text(AppStrings.signUp),
          ),
        ],
      );

  /// Handle navigation for driver users
  Future<void> _handleDriverNavigation(
    BuildContext context,
    String userId,
  ) async {
    if (!context.mounted) return;

    try {
      final driverRepository = GetIt.instance<DriverRepository>();
      final connectivityService = GetIt.instance<ConnectivityService>();

      // Check if online
      final isOnline = await connectivityService.isOnline();

      if (!context.mounted) return;

      if (isOnline) {
        // Try to fetch driver from backend first
        print('LoginScreen: Online - fetching driver from backend...');
        final backendResult = await driverRepository.fetchDriverFromBackend(userId);

        if (!context.mounted) return;

        await backendResult.fold(
          (failure) async {
            // Backend fetch failed, check local database
            print('LoginScreen: Backend fetch failed - ${failure.message}, checking local DB...');
            await _checkLocalDriverRecord(context, userId, driverRepository);
          },
          (driver) {
            // Successfully fetched from backend and synced to local DB
            print('LoginScreen: Driver found on backend - Status: ${driver.status.name}');
            if (context.mounted) {
              // Navigate based on driver status
              if (driver.status.name == 'approved') {
                print('LoginScreen: Driver approved, navigating to home');
                context.go(RoutePaths.driverHome);
              } else {
                print('LoginScreen: Driver not approved, navigating to status screen');
                context.go(RoutePaths.driverStatus);
              }
            }
          },
        );
      } else {
        // Offline - check local database only
        print('LoginScreen: Offline - checking local database...');
        await _checkLocalDriverRecord(context, userId, driverRepository);
      }
    } catch (e) {
      print('LoginScreen: Error handling driver navigation: $e');
      // On error, default to onboarding
      if (context.mounted) {
        context.go(RoutePaths.driverOnboarding);
      }
    }
  }

  /// Check local database for driver record
  Future<void> _checkLocalDriverRecord(
    BuildContext context,
    String userId,
    DriverRepository driverRepository,
  ) async {
    final localResult = await driverRepository.getDriverByUserId(userId);

    if (!context.mounted) return;

    localResult.fold(
      (failure) {
        // No driver record found - navigate to onboarding
        print('LoginScreen: No driver record found locally, navigating to onboarding');
        if (context.mounted) {
          context.go(RoutePaths.driverOnboarding);
        }
      },
      (driver) {
        // Driver record exists - navigate based on status
        print('LoginScreen: Driver record found locally - Status: ${driver.status.name}');
        if (context.mounted) {
          if (driver.status.name == 'approved') {
            print('LoginScreen: Driver approved, navigating to home');
            context.go(RoutePaths.driverHome);
          } else {
            print('LoginScreen: Driver not approved, navigating to status screen');
            context.go(RoutePaths.driverStatus);
          }
        }
      },
    );
  }
}
