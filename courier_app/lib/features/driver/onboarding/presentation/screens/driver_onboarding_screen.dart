import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:delivery_app/core/routing/route_names.dart';

class DriverOnboardingScreen extends StatefulWidget {
  const DriverOnboardingScreen({super.key});

  @override
  State<DriverOnboardingScreen> createState() => _DriverOnboardingScreenState();
}

class _DriverOnboardingScreenState extends State<DriverOnboardingScreen> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _licenseController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehiclePlateController = TextEditingController();
  final _vehicleYearController = TextEditingController();

  @override
  void dispose() {
    _licenseController.dispose();
    _vehicleModelController.dispose();
    _vehiclePlateController.dispose();
    _vehicleYearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Driver Onboarding'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // Navigate back to login
              context.go(RoutePaths.login);
            },
          ),
        ),
        body: Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: Theme.of(context).primaryColor,
                ),
          ),
          child: Stepper(
            currentStep: _currentStep,
            onStepContinue: _onStepContinue,
            onStepCancel: _onStepCancel,
            onStepTapped: (step) => setState(() => _currentStep = step),
            steps: [
              Step(
                title: const Text('Personal Information'),
                content: _buildPersonalInfoStep(),
                isActive: _currentStep >= 0,
                state: _currentStep > 0
                    ? StepState.complete
                    : StepState.indexed,
              ),
              Step(
                title: const Text('Vehicle Information'),
                content: _buildVehicleInfoStep(),
                isActive: _currentStep >= 1,
                state: _currentStep > 1
                    ? StepState.complete
                    : StepState.indexed,
              ),
              Step(
                title: const Text('Document Upload'),
                content: _buildDocumentUploadStep(),
                isActive: _currentStep >= 2,
                state: _currentStep > 2
                    ? StepState.complete
                    : StepState.indexed,
              ),
              Step(
                title: const Text('Review & Submit'),
                content: _buildReviewStep(),
                isActive: _currentStep >= 3,
                state: _currentStep == 3
                    ? StepState.indexed
                    : StepState.disabled,
              ),
            ],
          ),
        ),
      );

  Widget _buildPersonalInfoStep() => Form(
        key: _formKey,
        child: Column(
          children: [
            const SizedBox(height: 16),
            TextFormField(
              controller: _licenseController,
              decoration: const InputDecoration(
                labelText: 'Driver License Number',
                prefixIcon: Icon(Icons.badge),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your license number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Your personal information has been imported from your registration.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  Widget _buildVehicleInfoStep() => Column(
        children: [
          const SizedBox(height: 16),
          TextFormField(
            controller: _vehicleModelController,
            decoration: const InputDecoration(
              labelText: 'Vehicle Model',
              prefixIcon: Icon(Icons.directions_car),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _vehiclePlateController,
            decoration: const InputDecoration(
              labelText: 'License Plate',
              prefixIcon: Icon(Icons.confirmation_number),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _vehicleYearController,
            decoration: const InputDecoration(
              labelText: 'Vehicle Year',
              prefixIcon: Icon(Icons.calendar_today),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      );

  Widget _buildDocumentUploadStep() => Column(
        children: [
          const SizedBox(height: 16),
          _buildUploadCard(
            title: 'Driver License',
            icon: Icons.badge,
            isUploaded: false,
          ),
          const SizedBox(height: 16),
          _buildUploadCard(
            title: 'Vehicle Registration',
            icon: Icons.directions_car,
            isUploaded: false,
          ),
          const SizedBox(height: 16),
          _buildUploadCard(
            title: 'Insurance Document',
            icon: Icons.security,
            isUploaded: false,
          ),
          const SizedBox(height: 16),
          const Text(
            'Tap on each card to upload the required document',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      );

  Widget _buildUploadCard({
    required String title,
    required IconData icon,
    required bool isUploaded,
  }) =>
      Card(
        elevation: 2,
        child: InkWell(
          onTap: () {
            // TODO: Implement document upload
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Upload $title functionality coming soon'),
              ),
            );
          },
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 40,
                  color: isUploaded ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        isUploaded ? 'Uploaded' : 'Tap to upload',
                        style: TextStyle(
                          fontSize: 14,
                          color: isUploaded ? Colors.green : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isUploaded ? Icons.check_circle : Icons.upload,
                  color: isUploaded ? Colors.green : Colors.grey,
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildReviewStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text(
            'Review Your Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildReviewItem('License Number', _licenseController.text),
          _buildReviewItem('Vehicle Model', _vehicleModelController.text),
          _buildReviewItem('License Plate', _vehiclePlateController.text),
          _buildReviewItem('Vehicle Year', _vehicleYearController.text),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _submitOnboarding,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Submit for Verification',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Your application will be reviewed within 24-48 hours. You will receive a notification once approved.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      );

  Widget _buildReviewItem(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(
                '$label:',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value.isEmpty ? 'Not provided' : value,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );

  void _onStepContinue() {
    if (_currentStep < 3) {
      setState(() {
        _currentStep++;
      });
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  void _submitOnboarding() {
    // TODO: Implement API call to submit onboarding data
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Application submitted successfully!'),
        backgroundColor: Colors.green,
      ),
    );

    // For now, navigate to driver home (in real app, would wait for approval)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        context.go(RoutePaths.driverHome);
      }
    });
  }
}