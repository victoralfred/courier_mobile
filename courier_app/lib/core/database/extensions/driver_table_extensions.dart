import 'package:delivery_app/core/database/app_database.dart';

/// Extension methods for DriverTableData to support sync operations
extension DriverTableDataExtensions on DriverTableData {
  /// Converts DriverTableData to JSON map for API sync
  Map<String, dynamic> toJsonMap() => {
        'id': id,
        'userId': userId,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'licenseNumber': licenseNumber,
        'vehicleInfo': {
          'plate': vehiclePlate,
          'type': vehicleType,
          'make': vehicleMake,
          'model': vehicleModel,
          'year': vehicleYear,
          'color': vehicleColor,
        },
        'status': status,
        'availability': availability,
        if (currentLatitude != null && currentLongitude != null)
          'currentLocation': {
            'latitude': currentLatitude,
            'longitude': currentLongitude,
          },
        if (lastLocationUpdate != null)
          'lastLocationUpdate': lastLocationUpdate!.toIso8601String(),
        'rating': rating,
        'totalRatings': totalRatings,
      };

  /// Converts to JSON map for driver registration (create operation)
  Map<String, dynamic> toRegistrationJson() => {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'licenseNumber': licenseNumber,
        'vehicleInfo': {
          'plate': vehiclePlate,
          'type': vehicleType,
          'make': vehicleMake,
          'model': vehicleModel,
          'year': vehicleYear,
          'color': vehicleColor,
        },
      };

  /// Converts to JSON map for driver profile update
  Map<String, dynamic> toUpdateJson() => {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'licenseNumber': licenseNumber,
        'vehicleInfo': {
          'plate': vehiclePlate,
          'type': vehicleType,
          'make': vehicleMake,
          'model': vehicleModel,
          'year': vehicleYear,
          'color': vehicleColor,
        },
      };
}
