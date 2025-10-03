import 'package:flutter/material.dart';
import 'package:delivery_app/features/drivers/domain/entities/driver.dart';

/// Dialog shown when driver application is rejected
class RejectionDialog extends StatelessWidget {
  final Driver driver;
  final VoidCallback onReapply;

  const RejectionDialog({
    super.key,
    required this.driver,
    required this.onReapply,
  });

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange, size: 32),
            SizedBox(width: 12),
            Expanded(child: Text('Application Status Update')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Unfortunately, your application was not approved at this time.',
              style: TextStyle(fontSize: 16),
            ),
            if (driver.rejectionReason != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reason:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red[900],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      driver.rejectionReason!,
                      style: TextStyle(color: Colors.red[800]),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What you can do:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('• Review the requirements'),
                  Text('• Ensure all documents are valid and clear'),
                  Text('• Update your information if needed'),
                  Text('• Reapply when ready'),
                ],
              ),
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
              onReapply();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reapply Now'),
          ),
        ],
      );
}
