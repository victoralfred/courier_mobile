import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:delivery_app/core/routing/route_names.dart';
import 'package:delivery_app/features/auth/domain/entities/user_role.dart';
import 'package:delivery_app/features/auth/presentation/blocs/registration/registration_bloc.dart';
import 'package:delivery_app/features/auth/presentation/blocs/registration/registration_event.dart';
import 'package:delivery_app/features/auth/presentation/blocs/registration/registration_state.dart';

class RegistrationScreen extends StatelessWidget {
  const RegistrationScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.registrationTitle),
        ),
        body: SafeArea(
          child: BlocConsumer<RegistrationBloc, RegistrationState>(
            listener: (context, state) {
              if (state.status == RegistrationStatus.failure &&
                  state.generalError != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.generalError!),
                    backgroundColor: Colors.red,
                  ),
                );
              } else if (state.status == RegistrationStatus.success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(AppStrings.registrationSuccess),
                    backgroundColor: Colors.green,
                  ),
                );
                // Navigate to appropriate home based on role
                if (state.user != null) {
                  switch (state.user!.role.type) {
                    case UserRoleType.customer:
                      context.go(RoutePaths.customerHome);
                      break;
                    case UserRoleType.driver:
                      // New drivers need onboarding
                      context.go(RoutePaths.driverOnboarding);
                      break;
                  }
                } else {
                  // Fallback to login if no user
                  context.go(RoutePaths.login);
                }
              }
            },
            builder: (context, state) => SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildRoleSelection(context, state),
                  const SizedBox(height: 24),
                  _buildNameFields(context, state),
                  const SizedBox(height: 16),
                  _buildEmailField(context, state),
                  const SizedBox(height: 16),
                  _buildPhoneField(context, state),
                  const SizedBox(height: 16),
                  _buildPasswordField(context, state),
                  const SizedBox(height: 8),
                  _buildPasswordStrengthIndicator(state),
                  const SizedBox(height: 16),
                  _buildConfirmPasswordField(context, state),
                  const SizedBox(height: 24),
                  _buildTermsCheckbox(context, state),
                  const SizedBox(height: 24),
                  _buildRegisterButton(context, state),
                  const SizedBox(height: 16),
                  _buildSignInLink(context),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _buildRoleSelection(BuildContext context, RegistrationState state) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            AppStrings.selectRoleTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildRoleCard(
                  context: context,
                  role: UserRoleType.customer,
                  icon: Icons.shopping_cart,
                  label: AppStrings.roleCustomerOption,
                  isSelected: state.selectedRole == UserRoleType.customer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildRoleCard(
                  context: context,
                  role: UserRoleType.driver,
                  icon: Icons.local_shipping,
                  label: AppStrings.roleDriverOption,
                  isSelected: state.selectedRole == UserRoleType.driver,
                ),
              ),
            ],
          ),
          if (state.selectedRole == null &&
              state.canSubmit == false &&
              state.termsAccepted)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                AppStrings.errorRoleRequired,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      );

  Widget _buildRoleCard({
    required BuildContext context,
    required UserRoleType role,
    required IconData icon,
    required String label,
    required bool isSelected,
  }) =>
      InkWell(
        onTap: () {
          context.read<RegistrationBloc>().add(RegistrationRoleSelected(role));
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color: isSelected
                ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 40,
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.grey[600],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildNameFields(BuildContext context, RegistrationState state) => Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (firstName) {
                context
                    .read<RegistrationBloc>()
                    .add(RegistrationFirstNameChanged(firstName));
              },
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: AppStrings.firstNameLabel,
                errorText: state.firstNameError,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              onChanged: (lastName) {
                context
                    .read<RegistrationBloc>()
                    .add(RegistrationLastNameChanged(lastName));
              },
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: AppStrings.lastNameLabel,
                errorText: state.lastNameError,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        ],
      );

  Widget _buildEmailField(BuildContext context, RegistrationState state) =>
      TextField(
        onChanged: (email) {
          context.read<RegistrationBloc>().add(RegistrationEmailChanged(email));
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

  Widget _buildPhoneField(BuildContext context, RegistrationState state) =>
      TextField(
        onChanged: (phone) {
          context.read<RegistrationBloc>().add(RegistrationPhoneChanged(phone));
        },
        keyboardType: TextInputType.phone,
        decoration: InputDecoration(
          labelText: AppStrings.phoneLabel,
          errorText: state.phoneError,
          prefixIcon: const Icon(Icons.phone_outlined),
          prefixText: '+234 ',
          border: const OutlineInputBorder(),
        ),
      );

  Widget _buildPasswordField(BuildContext context, RegistrationState state) =>
      TextField(
        onChanged: (password) {
          context
              .read<RegistrationBloc>()
              .add(RegistrationPasswordChanged(password));
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
                  .read<RegistrationBloc>()
                  .add(const RegistrationPasswordVisibilityToggled());
            },
          ),
          border: const OutlineInputBorder(),
        ),
      );

  Widget _buildPasswordStrengthIndicator(RegistrationState state) {
    if (state.password.isEmpty) return const SizedBox.shrink();

    String strengthText;
    Color strengthColor;

    switch (state.passwordStrength) {
      case 0:
      case 1:
        strengthText = AppStrings.passwordStrengthWeak;
        strengthColor = Colors.red;
        break;
      case 2:
        strengthText = AppStrings.passwordStrengthFair;
        strengthColor = Colors.orange;
        break;
      case 3:
        strengthText = AppStrings.passwordStrengthGood;
        strengthColor = Colors.amber;
        break;
      case 4:
        strengthText = AppStrings.passwordStrengthStrong;
        strengthColor = Colors.green;
        break;
      default:
        strengthText = AppStrings.passwordStrengthWeak;
        strengthColor = Colors.red;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
          value: state.passwordStrength / 4,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
        ),
        const SizedBox(height: 4),
        Text(
          'Password Strength: $strengthText',
          style: TextStyle(
            fontSize: 12,
            color: strengthColor,
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmPasswordField(
          BuildContext context, RegistrationState state) =>
      TextField(
        onChanged: (confirmPassword) {
          context
              .read<RegistrationBloc>()
              .add(RegistrationConfirmPasswordChanged(confirmPassword));
        },
        obscureText: !state.isConfirmPasswordVisible,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: AppStrings.confirmPasswordLabel,
          errorText: state.confirmPasswordError,
          prefixIcon: const Icon(Icons.lock_outlined),
          suffixIcon: IconButton(
            icon: Icon(
              state.isConfirmPasswordVisible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            onPressed: () {
              context
                  .read<RegistrationBloc>()
                  .add(const RegistrationConfirmPasswordVisibilityToggled());
            },
          ),
          border: const OutlineInputBorder(),
        ),
      );

  Widget _buildTermsCheckbox(BuildContext context, RegistrationState state) =>
      Row(
        children: [
          Checkbox(
            value: state.termsAccepted,
            onChanged: (value) {
              context
                  .read<RegistrationBloc>()
                  .add(RegistrationTermsAccepted(value ?? false));
            },
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                context
                    .read<RegistrationBloc>()
                    .add(RegistrationTermsAccepted(!state.termsAccepted));
              },
              child: const Text(AppStrings.termsAndConditions),
            ),
          ),
        ],
      );

  Widget _buildRegisterButton(BuildContext context, RegistrationState state) =>
      SizedBox(
        height: 48,
        child: ElevatedButton(
          onPressed: state.canSubmit && !state.isLoading
              ? () {
                  context
                      .read<RegistrationBloc>()
                      .add(const RegistrationSubmitted());
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
                  AppStrings.registerButton,
                  style: TextStyle(fontSize: 16),
                ),
        ),
      );

  Widget _buildSignInLink(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(AppStrings.alreadyHaveAccount),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text(AppStrings.signIn),
          ),
        ],
      );
}
