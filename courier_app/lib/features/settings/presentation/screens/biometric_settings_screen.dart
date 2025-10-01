import 'package:flutter/material.dart';
import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:delivery_app/features/auth/domain/services/biometric_service.dart';
import 'package:get_it/get_it.dart';

/// Screen for managing biometric authentication settings
class BiometricSettingsScreen extends StatefulWidget {
  const BiometricSettingsScreen({super.key});

  @override
  State<BiometricSettingsScreen> createState() =>
      _BiometricSettingsScreenState();
}

class _BiometricSettingsScreenState extends State<BiometricSettingsScreen> {
  final _biometricService = GetIt.instance<BiometricService>();

  bool _isLoading = true;
  bool _isBiometricAvailable = false;
  bool _isBiometricEnabled = false;
  String _availableBiometricTypes = '';

  @override
  void initState() {
    super.initState();
    _loadBiometricStatus();
  }

  Future<void> _loadBiometricStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final isAvailable = await _biometricService.isAvailable();
      final isEnabled = await _biometricService.isBiometricEnabled();
      final biometrics = await _biometricService.getAvailableBiometrics();

      final types = biometrics.map((type) {
        switch (type.name) {
          case 'face':
            return 'Face ID';
          case 'fingerprint':
            return 'Fingerprint';
          case 'iris':
            return 'Iris';
          default:
            return 'Biometric';
        }
      }).join(', ');

      setState(() {
        _isBiometricAvailable = isAvailable;
        _isBiometricEnabled = isEnabled;
        _availableBiometricTypes = types.isEmpty ? 'None' : types;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleBiometric(bool enabled) async {
    setState(() {
      _isLoading = true;
    });

    try {
      bool success;
      if (enabled) {
        // Test biometric authentication before enabling
        final authenticated = await _biometricService.authenticate(
          localizedReason: 'Verify your identity to enable biometric login',
        );

        if (!authenticated) {
          if (mounted) {
            _showMessage(AppStrings.biometricFailed, isError: true);
          }
          setState(() {
            _isLoading = false;
          });
          return;
        }

        success = await _biometricService.enableBiometric();
      } else {
        success = await _biometricService.disableBiometric();
      }

      if (mounted) {
        if (success) {
          _showMessage(
            enabled
                ? AppStrings.biometricEnabled
                : AppStrings.biometricDisabled,
          );
          setState(() {
            _isBiometricEnabled = enabled;
          });
        } else {
          _showMessage(
            enabled
                ? AppStrings.biometricEnableFailed
                : AppStrings.biometricDisableFailed,
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showMessage(AppStrings.errorUnexpected, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.biometricSettingsTitle),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.biometricSettingsTitle,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppStrings.biometricSettingsDescription,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildStatusCard(context),
                  const SizedBox(height: 16),
                  if (_isBiometricAvailable) _buildToggleCard(context),
                  if (!_isBiometricAvailable) _buildUnavailableCard(context),
                ],
              ),
      );

  Widget _buildStatusCard(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow(
                context,
                'Device Support',
                _isBiometricAvailable ? 'Available' : 'Not Available',
                _isBiometricAvailable ? Icons.check_circle : Icons.cancel,
                _isBiometricAvailable ? Colors.green : Colors.red,
              ),
              const Divider(),
              _buildInfoRow(
                context,
                'Available Types',
                _availableBiometricTypes,
                Icons.fingerprint,
                Theme.of(context).primaryColor,
              ),
              const Divider(),
              _buildInfoRow(
                context,
                'Current Status',
                _isBiometricEnabled ? 'Enabled' : 'Disabled',
                _isBiometricEnabled ? Icons.lock : Icons.lock_open,
                _isBiometricEnabled ? Colors.green : Colors.grey,
              ),
            ],
          ),
        ),
      );

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildToggleCard(BuildContext context) => Card(
        child: SwitchListTile(
          title: const Text('Enable Biometric Login'),
          subtitle: const Text('Use biometric authentication to login'),
          value: _isBiometricEnabled,
          onChanged: _isLoading ? null : _toggleBiometric,
          secondary: Icon(
            Icons.fingerprint,
            color: Theme.of(context).primaryColor,
          ),
        ),
      );

  Widget _buildUnavailableCard(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(
                Icons.info_outline,
                size: 48,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.biometricNotAvailable,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Please ensure biometric authentication is set up on your device.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}
