import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:delivery_app/core/network/connectivity_service.dart';
import 'package:delivery_app/core/routing/route_names.dart';
import 'package:delivery_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:delivery_app/features/drivers/domain/repositories/driver_repository.dart';
import 'package:delivery_app/features/drivers/domain/entities/driver.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/driver_status.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/availability_status.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/vehicle_info.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/vehicle_type.dart';

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
  final _vehicleMakeController = TextEditingController();
  final _vehicleColorController = TextEditingController();

  bool _isSubmitting = false;
  bool _isCheckingAuth = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    try {
      final authRepository = GetIt.instance<AuthRepository>();
      final userResult = await authRepository.getCurrentUser();

      setState(() {
        _isAuthenticated = userResult.isRight();
        _isCheckingAuth = false;
      });

      if (!_isAuthenticated) {
        // Show dialog and redirect to login
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Authentication Required'),
              content: const Text(
                'You need to be logged in to register as a driver. Please log in first.',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Navigate to login with redirect back to driver onboarding
                    context.go('${RoutePaths.login}?redirect=${RoutePaths.driverOnboarding}');
                  },
                  child: const Text('Go to Login'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isCheckingAuth = false;
        _isAuthenticated = false;
      });
    }
  }

  @override
  void dispose() {
    _licenseController.dispose();
    _vehicleModelController.dispose();
    _vehiclePlateController.dispose();
    _vehicleYearController.dispose();
    _vehicleMakeController.dispose();
    _vehicleColorController.dispose();
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
        body: _isCheckingAuth
            ? const Center(child: CircularProgressIndicator())
            : !_isAuthenticated
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'Authentication Required',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text('Please log in to continue'),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            context.go('${RoutePaths.login}?redirect=${RoutePaths.driverOnboarding}');
                          },
                          child: const Text('Go to Login'),
                        ),
                      ],
                    ),
                  )
                : Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: Theme.of(context).primaryColor,
                ),
          ),
          child: Stepper(
            currentStep: _currentStep,
            onStepContinue: _currentStep == 3 ? null : _onStepContinue,
            onStepCancel: _onStepCancel,
            onStepTapped: (step) => setState(() => _currentStep = step),
            controlsBuilder: (context, details) {
              // Hide controls on last step (has custom submit button)
              if (_currentStep == 3) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  children: [
                    ElevatedButton(
                      onPressed: details.onStepContinue,
                      child: const Text('Continue'),
                    ),
                    const SizedBox(width: 8),
                    if (_currentStep > 0)
                      TextButton(
                        onPressed: details.onStepCancel,
                        child: const Text('Back'),
                      ),
                  ],
                ),
              );
            },
            steps: [
              Step(
                title: const Text('Personal Information'),
                content: _buildPersonalInfoStep(),
                isActive: _currentStep >= 0,
                state:
                    _currentStep > 0 ? StepState.complete : StepState.indexed,
              ),
              Step(
                title: const Text('Vehicle Information'),
                content: _buildVehicleInfoStep(),
                isActive: _currentStep >= 1,
                state:
                    _currentStep > 1 ? StepState.complete : StepState.indexed,
              ),
              Step(
                title: const Text('Document Upload'),
                content: _buildDocumentUploadStep(),
                isActive: _currentStep >= 2,
                state:
                    _currentStep > 2 ? StepState.complete : StepState.indexed,
              ),
              Step(
                title: const Text('Review & Submit'),
                content: _buildReviewStep(),
                isActive: _currentStep >= 3,
                state:
                    _currentStep == 3 ? StepState.indexed : StepState.disabled,
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
            controller: _vehicleMakeController,
            decoration: const InputDecoration(
              labelText: 'Vehicle Make',
              hintText: 'e.g., Toyota',
              prefixIcon: Icon(Icons.directions_car),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _vehicleModelController,
            decoration: const InputDecoration(
              labelText: 'Vehicle Model',
              hintText: 'e.g., Corolla',
              prefixIcon: Icon(Icons.car_repair),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _vehiclePlateController,
            decoration: const InputDecoration(
              labelText: 'License Plate',
              hintText: 'e.g., ABC-123-XY',
              prefixIcon: Icon(Icons.confirmation_number),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _vehicleYearController,
            decoration: const InputDecoration(
              labelText: 'Vehicle Year',
              hintText: 'e.g., 2020',
              prefixIcon: Icon(Icons.calendar_today),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _vehicleColorController,
            decoration: const InputDecoration(
              labelText: 'Vehicle Color',
              hintText: 'e.g., Silver',
              prefixIcon: Icon(Icons.palette),
              border: OutlineInputBorder(),
            ),
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
          _buildReviewItem('Vehicle Make', _vehicleMakeController.text),
          _buildReviewItem('Vehicle Model', _vehicleModelController.text),
          _buildReviewItem('License Plate', _vehiclePlateController.text),
          _buildReviewItem('Vehicle Year', _vehicleYearController.text),
          _buildReviewItem('Vehicle Color', _vehicleColorController.text),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitOnboarding,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
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
    // Validate current step before continuing
    if (_currentStep == 0) {
      // Step 0: Personal Info
      if (_licenseController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter your driver license number'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } else if (_currentStep == 1) {
      // Step 1: Vehicle Info
      if (_vehicleMakeController.text.trim().isEmpty ||
          _vehicleModelController.text.trim().isEmpty ||
          _vehiclePlateController.text.trim().isEmpty ||
          _vehicleYearController.text.trim().isEmpty ||
          _vehicleColorController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill in all vehicle information'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Validate year is a number
      final year = int.tryParse(_vehicleYearController.text.trim());
      if (year == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid vehicle year'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

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

  Future<void> _submitOnboarding() async {
    if (_isSubmitting) return;

    // Validate all required fields
    if (_licenseController.text.trim().isEmpty ||
        _vehicleMakeController.text.trim().isEmpty ||
        _vehicleModelController.text.trim().isEmpty ||
        _vehiclePlateController.text.trim().isEmpty ||
        _vehicleYearController.text.trim().isEmpty ||
        _vehicleColorController.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Get current user
      final authRepository = GetIt.instance<AuthRepository>();
      final userResult = await authRepository.getCurrentUser();

      final user = userResult.fold(
        (failure) => throw Exception('User not found: ${failure.message}'),
        (user) => user,
      );

      // Parse vehicle year
      final year = int.tryParse(_vehicleYearController.text.trim());
      if (year == null) {
        throw Exception('Invalid vehicle year');
      }

      // Create vehicle info
      final vehicleInfo = VehicleInfo(
        plate: _vehiclePlateController.text.trim(),
        type: VehicleType.car, // Default to car for now
        make: _vehicleMakeController.text.trim(),
        model: _vehicleModelController.text.trim(),
        year: year,
        color: _vehicleColorController.text.trim(),
      );

      // Create driver entity
      final driver = Driver(
        id: const Uuid().v4(),
        userId: user.id.value,
        firstName: user.firstName,
        lastName: user.lastName,
        email: user.email.value,
        phone: user.phone.value,
        licenseNumber: _licenseController.text.trim(),
        vehicleInfo: vehicleInfo,
        status: DriverStatus.pending, // Pending approval
        availability: AvailabilityStatus.offline, // Start offline
        rating: 0.0,
        totalRatings: 0,
      );

      // Save to database via repository
      final driverRepository = GetIt.instance<DriverRepository>();
      final result = await driverRepository.upsertDriver(driver);

      await result.fold(
        (failure) {
          throw Exception('Failed to save driver: ${failure.message}');
        },
        (savedDriver) async {
          if (!mounted) return;

          // Trigger immediate sync if online
          final connectivityService = GetIt.instance<ConnectivityService>();
          final syncedSuccessfully = await connectivityService.checkAndSync();

          if (!mounted) return;

          // Show success dialog with appropriate message
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 32),
                  SizedBox(width: 12),
                  Text('Application Submitted!'),
                ],
              ),
              content: Text(
                syncedSuccessfully
                    ? 'Your driver application has been submitted to our servers successfully.\n\n'
                      'Our team will review your application within 24-48 hours. '
                      'You will receive a notification once your application is approved.\n\n'
                      'You can view your application status in the driver section.'
                    : 'Your driver application has been saved locally.\n\n'
                      'It will be submitted automatically when you have an internet connection.\n\n'
                      'You can view your application status in the driver section.',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Navigate to driver status page instead of login
                    context.go(RoutePaths.driverStatus);
                  },
                  child: const Text('View Status'),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
