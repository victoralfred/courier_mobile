import 'package:flutter/material.dart';
import 'package:delivery_app/core/constants/app_strings.dart';

/// Dialog for fallback authentication when biometric fails
/// Shows either PIN or password input based on configuration
class BiometricFallbackDialog extends StatefulWidget {
  final bool usePinFallback;
  final Function(String) onAuthenticate;
  final VoidCallback? onCancel;

  const BiometricFallbackDialog({
    super.key,
    this.usePinFallback = false,
    required this.onAuthenticate,
    this.onCancel,
  });

  @override
  State<BiometricFallbackDialog> createState() =>
      _BiometricFallbackDialogState();
}

class _BiometricFallbackDialogState extends State<BiometricFallbackDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscureText = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await widget.onAuthenticate(_controller.text);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.usePinFallback
                  ? AppStrings.errorInvalidCredentials
                  : AppStrings.errorInvalidCredentials,
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(
          widget.usePinFallback
              ? AppStrings.biometricPinFallbackTitle
              : AppStrings.biometricPasswordFallbackTitle,
        ),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.usePinFallback
                    ? AppStrings.biometricPinFallbackMessage
                    : AppStrings.biometricPasswordFallbackMessage,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _controller,
                obscureText: _obscureText,
                keyboardType: widget.usePinFallback
                    ? TextInputType.number
                    : TextInputType.text,
                maxLength: widget.usePinFallback ? 6 : null,
                decoration: InputDecoration(
                  labelText: widget.usePinFallback
                      ? AppStrings.biometricPinFallbackTitle
                      : AppStrings.biometricPasswordFallbackTitle,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return widget.usePinFallback
                        ? 'PIN is required'
                        : AppStrings.validationPasswordRequired;
                  }
                  if (widget.usePinFallback && value.length < 4) {
                    return 'PIN must be at least 4 digits';
                  }
                  if (!widget.usePinFallback && value.length < 8) {
                    return AppStrings.validationPasswordTooShort;
                  }
                  return null;
                },
                autofocus: true,
                enabled: !_isLoading,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading
                ? null
                : () {
                    Navigator.of(context).pop(false);
                    widget.onCancel?.call();
                  },
            child: const Text(AppStrings.buttonCancel),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleSubmit,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Text(AppStrings.buttonContinue),
          ),
        ],
      );
}
