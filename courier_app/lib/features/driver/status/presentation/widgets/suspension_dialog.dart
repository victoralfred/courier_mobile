import 'package:flutter/material.dart';
import 'package:delivery_app/features/drivers/domain/entities/driver.dart';

/// Dialog shown when driver account is suspended
class SuspensionDialog extends StatelessWidget {
  final Driver driver;
  final VoidCallback onContactSupport;

  const SuspensionDialog({
    super.key,
    required this.driver,
    required this.onContactSupport,
  });

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange, size: 32),
            SizedBox(width: 12),
            Expanded(child: Text('Account Suspended')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your driver account has been temporarily suspended.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (driver.suspensionReason != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reason:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(driver.suspensionReason!),
                    if (driver.suspensionExpiresAt != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Suspension ends: ${_formatDate(driver.suspensionExpiresAt!)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Please contact our support team for more information or to resolve this issue.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onContactSupport();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Contact Support'),
          ),
        ],
      );

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
}
