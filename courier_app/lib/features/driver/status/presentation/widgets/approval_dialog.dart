import 'package:flutter/material.dart';
import 'package:delivery_app/features/drivers/domain/entities/driver.dart';

/// Dialog shown when driver application is approved
class ApprovalDialog extends StatelessWidget {
  final Driver driver;
  final VoidCallback onContinue;

  const ApprovalDialog({
    super.key,
    required this.driver,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.celebration, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Expanded(child: Text('Congratulations!')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your driver application has been approved!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'You can now start accepting delivery requests and earning money.',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next Steps:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('• Go to your driver dashboard'),
                  Text('• Set your availability to "Online"'),
                  Text('• Start accepting delivery requests'),
                  Text('• Track your earnings'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Welcome to the team!',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: onContinue,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text('Start Driving'),
          ),
        ],
      );
}
