import 'package:delivery_app/core/domain/value_objects/coordinate.dart';
import 'package:delivery_app/features/drivers/domain/entities/driver.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/availability_status.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/driver_status.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/vehicle_info.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/vehicle_type.dart';
import 'package:delivery_app/core/error/exceptions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Driver', () {
    // Test data setup
    final vehicleInfo = VehicleInfo(
      plate: 'ABC-123-XY',
      type: VehicleType.car,
      make: 'Toyota',
      model: 'Corolla',
      year: 2020,
      color: 'Silver',
    );

    final lagosCoordinate = Coordinate(latitude: 6.5244, longitude: 3.3792);

    group('constructor', () {
      test('should create Driver with all required fields', () {
        // Arrange & Act
        final driver = Driver(
          id: 'driver-123',
          userId: 'user-456',
          firstName: 'John',
          lastName: 'Doe',
          email: 'john.doe@example.com',
          phone: '+2348012345678',
          licenseNumber: 'LAG-12345-AB',
          vehicleInfo: vehicleInfo,
          status: DriverStatus.approved,
          availability: AvailabilityStatus.available,
          rating: 4.5,
          totalRatings: 100,
        );

        // Assert
        expect(driver.id, 'driver-123');
        expect(driver.userId, 'user-456');
        expect(driver.firstName, 'John');
        expect(driver.lastName, 'Doe');
        expect(driver.email, 'john.doe@example.com');
        expect(driver.phone, '+2348012345678');
        expect(driver.licenseNumber, 'LAG-12345-AB');
        expect(driver.vehicleInfo, vehicleInfo);
        expect(driver.status, DriverStatus.approved);
        expect(driver.availability, AvailabilityStatus.available);
        expect(driver.currentLocation, null);
        expect(driver.lastLocationUpdate, null);
        expect(driver.rating, 4.5);
        expect(driver.totalRatings, 100);
      });

      test('should create Driver with optional location fields', () {
        // Arrange & Act
        final driver = Driver(
          id: 'driver-123',
          userId: 'user-456',
          firstName: 'John',
          lastName: 'Doe',
          email: 'john.doe@example.com',
          phone: '+2348012345678',
          licenseNumber: 'LAG-12345-AB',
          vehicleInfo: vehicleInfo,
          status: DriverStatus.approved,
          availability: AvailabilityStatus.busy,
          currentLocation: lagosCoordinate,
          lastLocationUpdate: DateTime(2025, 10, 2, 10, 30),
          rating: 4.8,
          totalRatings: 250,
        );

        // Assert
        expect(driver.currentLocation, lagosCoordinate);
        expect(driver.lastLocationUpdate, DateTime(2025, 10, 2, 10, 30));
      });

      test('should throw ValidationException for empty firstName', () {
        // Act & Assert
        expect(
          () => Driver(
            id: 'driver-123',
            userId: 'user-456',
            firstName: '',
            lastName: 'Doe',
            email: 'john.doe@example.com',
            phone: '+2348012345678',
            licenseNumber: 'LAG-12345-AB',
            vehicleInfo: vehicleInfo,
            status: DriverStatus.approved,
            availability: AvailabilityStatus.available,
            rating: 4.5,
            totalRatings: 100,
          ),
          throwsA(isA<ValidationException>()),
        );
      });

      test('should throw ValidationException for empty lastName', () {
        // Act & Assert
        expect(
          () => Driver(
            id: 'driver-123',
            userId: 'user-456',
            firstName: 'John',
            lastName: '',
            email: 'john.doe@example.com',
            phone: '+2348012345678',
            licenseNumber: 'LAG-12345-AB',
            vehicleInfo: vehicleInfo,
            status: DriverStatus.approved,
            availability: AvailabilityStatus.available,
            rating: 4.5,
            totalRatings: 100,
          ),
          throwsA(isA<ValidationException>()),
        );
      });

      test('should throw ValidationException for empty email', () {
        // Act & Assert
        expect(
          () => Driver(
            id: 'driver-123',
            userId: 'user-456',
            firstName: 'John',
            lastName: 'Doe',
            email: '',
            phone: '+2348012345678',
            licenseNumber: 'LAG-12345-AB',
            vehicleInfo: vehicleInfo,
            status: DriverStatus.approved,
            availability: AvailabilityStatus.available,
            rating: 4.5,
            totalRatings: 100,
          ),
          throwsA(isA<ValidationException>()),
        );
      });

      test('should throw ValidationException for invalid email format', () {
        // Act & Assert
        expect(
          () => Driver(
            id: 'driver-123',
            userId: 'user-456',
            firstName: 'John',
            lastName: 'Doe',
            email: 'invalid-email',
            phone: '+2348012345678',
            licenseNumber: 'LAG-12345-AB',
            vehicleInfo: vehicleInfo,
            status: DriverStatus.approved,
            availability: AvailabilityStatus.available,
            rating: 4.5,
            totalRatings: 100,
          ),
          throwsA(isA<ValidationException>()),
        );
      });

      test('should throw ValidationException for empty phone', () {
        // Act & Assert
        expect(
          () => Driver(
            id: 'driver-123',
            userId: 'user-456',
            firstName: 'John',
            lastName: 'Doe',
            email: 'john.doe@example.com',
            phone: '',
            licenseNumber: 'LAG-12345-AB',
            vehicleInfo: vehicleInfo,
            status: DriverStatus.approved,
            availability: AvailabilityStatus.available,
            rating: 4.5,
            totalRatings: 100,
          ),
          throwsA(isA<ValidationException>()),
        );
      });

      test('should throw ValidationException for empty licenseNumber', () {
        // Act & Assert
        expect(
          () => Driver(
            id: 'driver-123',
            userId: 'user-456',
            firstName: 'John',
            lastName: 'Doe',
            email: 'john.doe@example.com',
            phone: '+2348012345678',
            licenseNumber: '',
            vehicleInfo: vehicleInfo,
            status: DriverStatus.approved,
            availability: AvailabilityStatus.available,
            rating: 4.5,
            totalRatings: 100,
          ),
          throwsA(isA<ValidationException>()),
        );
      });

      test('should throw ValidationException for rating below 0', () {
        // Act & Assert
        expect(
          () => Driver(
            id: 'driver-123',
            userId: 'user-456',
            firstName: 'John',
            lastName: 'Doe',
            email: 'john.doe@example.com',
            phone: '+2348012345678',
            licenseNumber: 'LAG-12345-AB',
            vehicleInfo: vehicleInfo,
            status: DriverStatus.approved,
            availability: AvailabilityStatus.available,
            rating: -1.0,
            totalRatings: 100,
          ),
          throwsA(isA<ValidationException>()),
        );
      });

      test('should throw ValidationException for rating above 5', () {
        // Act & Assert
        expect(
          () => Driver(
            id: 'driver-123',
            userId: 'user-456',
            firstName: 'John',
            lastName: 'Doe',
            email: 'john.doe@example.com',
            phone: '+2348012345678',
            licenseNumber: 'LAG-12345-AB',
            vehicleInfo: vehicleInfo,
            status: DriverStatus.approved,
            availability: AvailabilityStatus.available,
            rating: 5.5,
            totalRatings: 100,
          ),
          throwsA(isA<ValidationException>()),
        );
      });

      test('should trim whitespace from string fields', () {
        // Arrange & Act
        final driver = Driver(
          id: 'driver-123',
          userId: 'user-456',
          firstName: '  John  ',
          lastName: '  Doe  ',
          email: '  john.doe@example.com  ',
          phone: '  +2348012345678  ',
          licenseNumber: '  LAG-12345-AB  ',
          vehicleInfo: vehicleInfo,
          status: DriverStatus.approved,
          availability: AvailabilityStatus.available,
          rating: 4.5,
          totalRatings: 100,
        );

        // Assert
        expect(driver.firstName, 'John');
        expect(driver.lastName, 'Doe');
        expect(driver.email, 'john.doe@example.com');
        expect(driver.phone, '+2348012345678');
        expect(driver.licenseNumber, 'LAG-12345-AB');
      });
    });

    group('fullName', () {
      test('should return concatenated first and last name', () {
        // Arrange
        final driver = Driver(
          id: 'driver-123',
          userId: 'user-456',
          firstName: 'John',
          lastName: 'Doe',
          email: 'john.doe@example.com',
          phone: '+2348012345678',
          licenseNumber: 'LAG-12345-AB',
          vehicleInfo: vehicleInfo,
          status: DriverStatus.approved,
          availability: AvailabilityStatus.available,
          rating: 4.5,
          totalRatings: 100,
        );

        // Act & Assert
        expect(driver.fullName, 'John Doe');
      });
    });

    group('status checks', () {
      test('isPending should return true for pending status', () {
        // Arrange
        final driver = Driver(
          id: 'driver-123',
          userId: 'user-456',
          firstName: 'John',
          lastName: 'Doe',
          email: 'john.doe@example.com',
          phone: '+2348012345678',
          licenseNumber: 'LAG-12345-AB',
          vehicleInfo: vehicleInfo,
          status: DriverStatus.pending,
          availability: AvailabilityStatus.offline,
          rating: 0.0,
          totalRatings: 0,
        );

        // Act & Assert
        expect(driver.isPending, true);
        expect(driver.isApproved, false);
      });

      test('isApproved should return true for approved status', () {
        // Arrange
        final driver = Driver(
          id: 'driver-123',
          userId: 'user-456',
          firstName: 'John',
          lastName: 'Doe',
          email: 'john.doe@example.com',
          phone: '+2348012345678',
          licenseNumber: 'LAG-12345-AB',
          vehicleInfo: vehicleInfo,
          status: DriverStatus.approved,
          availability: AvailabilityStatus.available,
          rating: 4.5,
          totalRatings: 100,
        );

        // Act & Assert
        expect(driver.isApproved, true);
        expect(driver.isPending, false);
      });

      test('isRejected should return true for rejected status', () {
        // Arrange
        final driver = Driver(
          id: 'driver-123',
          userId: 'user-456',
          firstName: 'John',
          lastName: 'Doe',
          email: 'john.doe@example.com',
          phone: '+2348012345678',
          licenseNumber: 'LAG-12345-AB',
          vehicleInfo: vehicleInfo,
          status: DriverStatus.rejected,
          availability: AvailabilityStatus.offline,
          rating: 0.0,
          totalRatings: 0,
        );

        // Act & Assert
        expect(driver.isRejected, true);
      });

      test('isSuspended should return true for suspended status', () {
        // Arrange
        final driver = Driver(
          id: 'driver-123',
          userId: 'user-456',
          firstName: 'John',
          lastName: 'Doe',
          email: 'john.doe@example.com',
          phone: '+2348012345678',
          licenseNumber: 'LAG-12345-AB',
          vehicleInfo: vehicleInfo,
          status: DriverStatus.suspended,
          availability: AvailabilityStatus.offline,
          rating: 4.5,
          totalRatings: 100,
        );

        // Act & Assert
        expect(driver.isSuspended, true);
      });
    });

    group('availability checks', () {
      test('isOnline should return true when available or busy', () {
        // Arrange
        final availableDriver = Driver(
          id: 'driver-123',
          userId: 'user-456',
          firstName: 'John',
          lastName: 'Doe',
          email: 'john.doe@example.com',
          phone: '+2348012345678',
          licenseNumber: 'LAG-12345-AB',
          vehicleInfo: vehicleInfo,
          status: DriverStatus.approved,
          availability: AvailabilityStatus.available,
          rating: 4.5,
          totalRatings: 100,
        );

        final busyDriver = availableDriver.copyWith(
          availability: AvailabilityStatus.busy,
        );

        // Act & Assert
        expect(availableDriver.isOnline, true);
        expect(busyDriver.isOnline, true);
      });

      test('isOnline should return false when offline', () {
        // Arrange
        final driver = Driver(
          id: 'driver-123',
          userId: 'user-456',
          firstName: 'John',
          lastName: 'Doe',
          email: 'john.doe@example.com',
          phone: '+2348012345678',
          licenseNumber: 'LAG-12345-AB',
          vehicleInfo: vehicleInfo,
          status: DriverStatus.approved,
          availability: AvailabilityStatus.offline,
          rating: 4.5,
          totalRatings: 100,
        );

        // Act & Assert
        expect(driver.isOnline, false);
      });

      test('canAcceptOrders should return true only when approved and available', () {
        // Arrange
        final approvedAvailable = Driver(
          id: 'driver-123',
          userId: 'user-456',
          firstName: 'John',
          lastName: 'Doe',
          email: 'john.doe@example.com',
          phone: '+2348012345678',
          licenseNumber: 'LAG-12345-AB',
          vehicleInfo: vehicleInfo,
          status: DriverStatus.approved,
          availability: AvailabilityStatus.available,
          rating: 4.5,
          totalRatings: 100,
        );

        final approvedBusy = approvedAvailable.copyWith(
          availability: AvailabilityStatus.busy,
        );

        final pendingAvailable = approvedAvailable.copyWith(
          status: DriverStatus.pending,
        );

        // Act & Assert
        expect(approvedAvailable.canAcceptOrders, true);
        expect(approvedBusy.canAcceptOrders, false);
        expect(pendingAvailable.canAcceptOrders, false);
      });
    });

    group('hasLocation', () {
      test('should return true when currentLocation is set', () {
        // Arrange
        final driver = Driver(
          id: 'driver-123',
          userId: 'user-456',
          firstName: 'John',
          lastName: 'Doe',
          email: 'john.doe@example.com',
          phone: '+2348012345678',
          licenseNumber: 'LAG-12345-AB',
          vehicleInfo: vehicleInfo,
          status: DriverStatus.approved,
          availability: AvailabilityStatus.available,
          currentLocation: lagosCoordinate,
          rating: 4.5,
          totalRatings: 100,
        );

        // Act & Assert
        expect(driver.hasLocation, true);
      });

      test('should return false when currentLocation is null', () {
        // Arrange
        final driver = Driver(
          id: 'driver-123',
          userId: 'user-456',
          firstName: 'John',
          lastName: 'Doe',
          email: 'john.doe@example.com',
          phone: '+2348012345678',
          licenseNumber: 'LAG-12345-AB',
          vehicleInfo: vehicleInfo,
          status: DriverStatus.approved,
          availability: AvailabilityStatus.available,
          rating: 4.5,
          totalRatings: 100,
        );

        // Act & Assert
        expect(driver.hasLocation, false);
      });
    });

    group('copyWith', () {
      test('should create copy with updated status', () {
        // Arrange
        final driver = Driver(
          id: 'driver-123',
          userId: 'user-456',
          firstName: 'John',
          lastName: 'Doe',
          email: 'john.doe@example.com',
          phone: '+2348012345678',
          licenseNumber: 'LAG-12345-AB',
          vehicleInfo: vehicleInfo,
          status: DriverStatus.pending,
          availability: AvailabilityStatus.offline,
          rating: 0.0,
          totalRatings: 0,
        );

        // Act
        final updated = driver.copyWith(status: DriverStatus.approved);

        // Assert
        expect(updated.status, DriverStatus.approved);
        expect(updated.id, driver.id); // Unchanged
      });

      test('should create copy with updated availability and location', () {
        // Arrange
        final driver = Driver(
          id: 'driver-123',
          userId: 'user-456',
          firstName: 'John',
          lastName: 'Doe',
          email: 'john.doe@example.com',
          phone: '+2348012345678',
          licenseNumber: 'LAG-12345-AB',
          vehicleInfo: vehicleInfo,
          status: DriverStatus.approved,
          availability: AvailabilityStatus.offline,
          rating: 4.5,
          totalRatings: 100,
        );

        // Act
        final updated = driver.copyWith(
          availability: AvailabilityStatus.available,
          currentLocation: lagosCoordinate,
          lastLocationUpdate: DateTime(2025, 10, 2, 10, 30),
        );

        // Assert
        expect(updated.availability, AvailabilityStatus.available);
        expect(updated.currentLocation, lagosCoordinate);
        expect(updated.lastLocationUpdate, DateTime(2025, 10, 2, 10, 30));
      });
    });

    group('equality', () {
      test('should be equal when all fields are same', () {
        // Arrange
        final driver1 = Driver(
          id: 'driver-123',
          userId: 'user-456',
          firstName: 'John',
          lastName: 'Doe',
          email: 'john.doe@example.com',
          phone: '+2348012345678',
          licenseNumber: 'LAG-12345-AB',
          vehicleInfo: vehicleInfo,
          status: DriverStatus.approved,
          availability: AvailabilityStatus.available,
          rating: 4.5,
          totalRatings: 100,
        );

        final driver2 = Driver(
          id: 'driver-123',
          userId: 'user-456',
          firstName: 'John',
          lastName: 'Doe',
          email: 'john.doe@example.com',
          phone: '+2348012345678',
          licenseNumber: 'LAG-12345-AB',
          vehicleInfo: vehicleInfo,
          status: DriverStatus.approved,
          availability: AvailabilityStatus.available,
          rating: 4.5,
          totalRatings: 100,
        );

        // Act & Assert
        expect(driver1, driver2);
        expect(driver1.hashCode, driver2.hashCode);
      });

      test('should not be equal when id differs', () {
        // Arrange
        final driver1 = Driver(
          id: 'driver-123',
          userId: 'user-456',
          firstName: 'John',
          lastName: 'Doe',
          email: 'john.doe@example.com',
          phone: '+2348012345678',
          licenseNumber: 'LAG-12345-AB',
          vehicleInfo: vehicleInfo,
          status: DriverStatus.approved,
          availability: AvailabilityStatus.available,
          rating: 4.5,
          totalRatings: 100,
        );

        final driver2 = Driver(
          id: 'driver-999',
          userId: 'user-456',
          firstName: 'John',
          lastName: 'Doe',
          email: 'john.doe@example.com',
          phone: '+2348012345678',
          licenseNumber: 'LAG-12345-AB',
          vehicleInfo: vehicleInfo,
          status: DriverStatus.approved,
          availability: AvailabilityStatus.available,
          rating: 4.5,
          totalRatings: 100,
        );

        // Act & Assert
        expect(driver1 == driver2, false);
      });
    });
  });
}
