import 'package:delivery_app/core/database/app_database.dart';
import 'package:delivery_app/core/domain/value_objects/coordinate.dart';
import 'package:delivery_app/features/drivers/domain/entities/driver.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/availability_status.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/driver_status.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/vehicle_info.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/vehicle_type.dart';

/// Mapper for converting between Driver domain entity and database model
class DriverMapper {
  /// Converts a [DriverTableData] to a [Driver] domain entity
  static Driver fromDatabase(DriverTableData data) => Driver(
        id: data.id,
        userId: data.userId,
        firstName: data.firstName,
        lastName: data.lastName,
        email: data.email,
        phone: data.phone,
        licenseNumber: data.licenseNumber,
        vehicleInfo: VehicleInfo(
          plate: data.vehiclePlate,
          type: _parseVehicleType(data.vehicleType),
          make: data.vehicleMake,
          model: data.vehicleModel,
          year: data.vehicleYear,
          color: data.vehicleColor,
        ),
        status: _parseDriverStatus(data.status),
        availability: _parseAvailabilityStatus(data.availability),
        currentLocation:
            data.currentLatitude != null && data.currentLongitude != null
                ? Coordinate(
                    latitude: data.currentLatitude!,
                    longitude: data.currentLongitude!,
                  )
                : null,
        lastLocationUpdate: data.lastLocationUpdate,
        rating: data.rating,
        totalRatings: data.totalRatings,
      );

  /// Converts a [Driver] domain entity to [DriverTableData]
  static DriverTableData toDatabase(Driver driver) => DriverTableData(
        id: driver.id,
        userId: driver.userId,
        firstName: driver.firstName,
        lastName: driver.lastName,
        email: driver.email,
        phone: driver.phone,
        licenseNumber: driver.licenseNumber,
        vehiclePlate: driver.vehicleInfo.plate,
        vehicleType: driver.vehicleInfo.type.name,
        vehicleMake: driver.vehicleInfo.make,
        vehicleModel: driver.vehicleInfo.model,
        vehicleYear: driver.vehicleInfo.year,
        vehicleColor: driver.vehicleInfo.color,
        status: driver.status.name,
        availability: driver.availability.name,
        currentLatitude: driver.currentLocation?.latitude,
        currentLongitude: driver.currentLocation?.longitude,
        lastLocationUpdate: driver.lastLocationUpdate,
        rating: driver.rating,
        totalRatings: driver.totalRatings,
        lastSyncedAt: null,
      );

  /// Parses vehicle type from string
  static VehicleType _parseVehicleType(String type) {
    switch (type.toLowerCase()) {
      case 'motorcycle':
        return VehicleType.motorcycle;
      case 'car':
        return VehicleType.car;
      case 'van':
        return VehicleType.van;
      case 'bicycle':
        return VehicleType.bicycle;
      default:
        return VehicleType.motorcycle; // Default fallback
    }
  }

  /// Parses driver status from string
  static DriverStatus _parseDriverStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return DriverStatus.pending;
      case 'approved':
        return DriverStatus.approved;
      case 'rejected':
        return DriverStatus.rejected;
      case 'suspended':
        return DriverStatus.suspended;
      default:
        return DriverStatus.pending; // Default fallback
    }
  }

  /// Parses availability status from string
  static AvailabilityStatus _parseAvailabilityStatus(String availability) {
    switch (availability.toLowerCase()) {
      case 'offline':
        return AvailabilityStatus.offline;
      case 'available':
        return AvailabilityStatus.available;
      case 'busy':
        return AvailabilityStatus.busy;
      default:
        return AvailabilityStatus.offline; // Default fallback
    }
  }
}
