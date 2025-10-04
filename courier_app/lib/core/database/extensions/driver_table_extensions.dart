import 'package:delivery_app/core/database/app_database.dart';

/// WHAT: Extension methods for DriverTableData database model serialization
///
/// WHY: Provides JSON conversion methods for syncing driver data with backend API.
/// Handles different API endpoint requirements (registration vs. updates) with
/// separate serialization methods. Separates serialization logic from table schema.
///
/// RESPONSIBILITIES:
/// - Convert DriverTableData to JSON for API requests
/// - Handle nested vehicle information object
/// - Support different formats for different endpoints (registration, update, sync)
/// - Handle snake_case vs camelCase field naming conventions
///
/// METHODS:
/// - toJsonMap(): Full driver data with camelCase (for general sync)
/// - toRegistrationJson(): Flat snake_case fields (for POST /api/v1/drivers/register)
/// - toUpdateJson(): Profile update format with nested vehicleInfo
///
/// API ENDPOINT COMPATIBILITY:
/// - POST /api/v1/drivers/register: Uses toRegistrationJson() (snake_case, flat)
/// - PUT /api/v1/drivers/:id: Uses toUpdateJson() (camelCase, nested)
/// - Generic sync: Uses toJsonMap() (full data, camelCase)
///
/// USAGE:
/// ```dart
/// // Driver registration (backend expects snake_case flat fields)
/// final registrationJson = driverData.toRegistrationJson();
/// // Result: {first_name, last_name, email, phone_number, license_number,
/// //          vehicle_type, vehicle_plate, vehicle_make, vehicle_model, vehicle_year}
///
/// // Driver profile update
/// final updateJson = driverData.toUpdateJson();
/// // Result: {firstName, lastName, email, phone, licenseNumber,
/// //          vehicleInfo: {plate, type, make, model, year, color}}
///
/// // Full sync
/// final syncJson = driverData.toJsonMap();
/// // Result: {id, userId, firstName, ..., vehicleInfo, status, availability,
/// //          currentLocation, rating, totalRatings}
///
/// // Queue for sync
/// await database.syncQueueDao.addToQueue(
///   entityType: 'driver',
///   entityId: driver.id,
///   operation: 'create',
///   payload: jsonEncode({
///     'endpoint': 'POST /api/v1/drivers/register',
///     'data': driverData.toRegistrationJson(),
///   }),
/// );
/// ```
///
/// IMPROVEMENT OPPORTUNITIES:
/// - [LOW] Add fromJson() factory methods for deserializing API responses
/// - [MEDIUM] Add validation for Nigeria phone number format (+234...)
/// - [LOW] Add toLocationUpdateJson() for location-only updates
/// - [MEDIUM] Validate geographic bounds (Nigeria: 4-14°N, 3-15°E)
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
  /// Backend expects snake_case flat fields
  Map<String, dynamic> toRegistrationJson() => {
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'phone_number': phone,
        'license_number': licenseNumber,
        'vehicle_type': vehicleType,
        'vehicle_plate': vehiclePlate,
        'vehicle_make': vehicleMake,
        'vehicle_model': vehicleModel,
        'vehicle_year': vehicleYear,
        // Note: vehicle_color is not required by backend
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
