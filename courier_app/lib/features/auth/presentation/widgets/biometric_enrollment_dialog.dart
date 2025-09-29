import 'package:flutter/material.dart';
import 'package:delivery_app/core/constants/app_strings.dart';

/// Dialog shown to user after successful login to enroll in biometric authentication
class BiometricEnrollmentDialog extends StatelessWidget {
  final VoidCallback onEnable;
  final VoidCallback onSkip;

  const BiometricEnrollmentDialog({
    super.key,
    required this.onEnable,
    required this.onSkip,
  });

  /// Show the enrollment dialog
  static Future<bool?> show({
    required BuildContext context,
    required VoidCallback onEnable,
    required VoidCallback onSkip,
  }) =>
      showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => BiometricEnrollmentDialog(
          onEnable: onEnable,
          onSkip: onSkip,
        ),
      );

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.fingerprint,
              color: Theme.of(context).primaryColor,
              size: 32,
            ),
            const SizedBox(width: 12),
            const Text(AppStrings.biometricEnrollmentTitle),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(AppStrings.biometricEnrollmentMessage),
            const SizedBox(height: 16),
            _buildBenefit(
              context,
              Icons.speed,
              'Faster login',
              'Quick access with fingerprint or face',
            ),
            const SizedBox(height: 8),
            _buildBenefit(
              context,
              Icons.security,
              'More secure',
              'Your biometric data never leaves your device',
            ),
            const SizedBox(height: 8),
            _buildBenefit(
              context,
              Icons.check_circle,
              'Convenient',
              'No need to remember passwords',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
              onSkip();
            },
            child: const Text(AppStrings.biometricEnrollmentNo),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(true);
              onEnable();
            },
            child: const Text(AppStrings.biometricEnrollmentYes),
          ),
        ],
      );

  Widget _buildBenefit(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      );
}
