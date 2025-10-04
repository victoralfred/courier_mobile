import 'package:delivery_app/core/domain/value_objects/coordinate.dart';
import 'package:delivery_app/features/drivers/domain/entities/driver.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/availability_status.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/driver_status.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/vehicle_info.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/vehicle_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Driver Entity - New Fields', () {
    final vehicleInfo = VehicleInfo(
      plate: 'ABC-123',
      type: VehicleType.car,
      make: 'Toyota',
      model: 'Camry',
      year: 2020,
      color: 'Silver',
    );

    test('should create driver with rejection reason', () {
      // Arrange & Act
      final driver = Driver(
        id: 'driver-123',
        userId: 'user-123',
        firstName: 'John',
        lastName: 'Doe',
        email: 'john@example.com',
        phone: '+2348012345678',
        licenseNumber: 'DL123456',
        vehicleInfo: vehicleInfo,
        status: DriverStatus.rejected,
        availability: AvailabilityStatus.offline,
        rating: 0.0,
        totalRatings: 0,
        rejectionReason: 'Invalid license document',
        statusUpdatedAt: DateTime(2025, 10, 3),
      );

      // Assert
      expect(driver.rejectionReason, 'Invalid license document');
      expect(driver.statusUpdatedAt, DateTime(2025, 10, 3));
      expect(driver.status, DriverStatus.rejected);
    });

    test('should create driver with suspension info', () {
      // Arrange & Act
      final driver = Driver(
        id: 'driver-123',
        userId: 'user-123',
        firstName: 'John',
        lastName: 'Doe',
        email: 'john@example.com',
        phone: '+2348012345678',
        licenseNumber: 'DL123456',
        vehicleInfo: vehicleInfo,
        status: DriverStatus.suspended,
        availability: AvailabilityStatus.offline,
        rating: 4.5,
        totalRatings: 100,
        suspensionReason: 'Multiple customer complaints',
        suspensionExpiresAt: DateTime(2025, 10, 10),
        statusUpdatedAt: DateTime(2025, 10, 3),
      );

      // Assert
      expect(driver.suspensionReason, 'Multiple customer complaints');
      expect(driver.suspensionExpiresAt, DateTime(2025, 10, 10));
      expect(driver.status, DriverStatus.suspended);
    });

    test('should allow null for optional status fields', () {
      // Arrange & Act
      final driver = Driver(
        id: 'driver-123',
        userId: 'user-123',
        firstName: 'John',
        lastName: 'Doe',
        email: 'john@example.com',
        phone: '+2348012345678',
        licenseNumber: 'DL123456',
        vehicleInfo: vehicleInfo,
        status: DriverStatus.pending,
        availability: AvailabilityStatus.offline,
        rating: 0.0,
        totalRatings: 0,
        rejectionReason: null,
        suspensionReason: null,
        suspensionExpiresAt: null,
        statusUpdatedAt: null,
      );

      // Assert
      expect(driver.rejectionReason, isNull);
      expect(driver.suspensionReason, isNull);
      expect(driver.suspensionExpiresAt, isNull);
      expect(driver.statusUpdatedAt, isNull);
    });

    test('should create approved driver without rejection or suspension info', () {
      // Arrange & Act
      final driver = Driver(
        id: 'driver-123',
        userId: 'user-123',
        firstName: 'John',
        lastName: 'Doe',
        email: 'john@example.com',
        phone: '+2348012345678',
        licenseNumber: 'DL123456',
        vehicleInfo: vehicleInfo,
        status: DriverStatus.approved,
        availability: AvailabilityStatus.available,
        rating: 4.8,
        totalRatings: 50,
        statusUpdatedAt: DateTime(2025, 10, 1),
      );

      // Assert
      expect(driver.status, DriverStatus.approved);
      expect(driver.rejectionReason, isNull);
      expect(driver.suspensionReason, isNull);
      expect(driver.suspensionExpiresAt, isNull);
      expect(driver.statusUpdatedAt, DateTime(2025, 10, 1));
    });

    test('should support copyWith for new fields', () {
      // Arrange
      final original = Driver(
        id: 'driver-123',
        userId: 'user-123',
        firstName: 'John',
        lastName: 'Doe',
        email: 'john@example.com',
        phone: '+2348012345678',
        licenseNumber: 'DL123456',
        vehicleInfo: vehicleInfo,
        status: DriverStatus.pending,
        availability: AvailabilityStatus.offline,
        rating: 0.0,
        totalRatings: 0,
      );

      // Act
      final updated = original.copyWith(
        status: DriverStatus.rejected,
        rejectionReason: 'Documents not clear',
        statusUpdatedAt: DateTime(2025, 10, 3),
      );

      // Assert
      expect(updated.id, original.id);
      expect(updated.status, DriverStatus.rejected);
      expect(updated.rejectionReason, 'Documents not clear');
      expect(updated.statusUpdatedAt, DateTime(2025, 10, 3));
      expect(original.status, DriverStatus.pending); // Original unchanged
    });

    test('should include new fields in equality comparison', () {
      // Arrange
      final driver1 = Driver(
        id: 'driver-123',
        userId: 'user-123',
        firstName: 'John',
        lastName: 'Doe',
        email: 'john@example.com',
        phone: '+2348012345678',
        licenseNumber: 'DL123456',
        vehicleInfo: vehicleInfo,
        status: DriverStatus.rejected,
        availability: AvailabilityStatus.offline,
        rating: 0.0,
        totalRatings: 0,
        rejectionReason: 'Invalid license',
      );

      final driver2 = Driver(
        id: 'driver-123',
        userId: 'user-123',
        firstName: 'John',
        lastName: 'Doe',
        email: 'john@example.com',
        phone: '+2348012345678',
        licenseNumber: 'DL123456',
        vehicleInfo: vehicleInfo,
        status: DriverStatus.rejected,
        availability: AvailabilityStatus.offline,
        rating: 0.0,
        totalRatings: 0,
        rejectionReason: 'Invalid license',
      );

      final driver3 = driver1.copyWith(
        rejectionReason: 'Different reason',
      );

      // Assert
      expect(driver1, equals(driver2)); // Same rejection reason
      expect(driver1, isNot(equals(driver3))); // Different rejection reason
    });
  });
}
