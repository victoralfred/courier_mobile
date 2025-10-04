import 'package:delivery_app/core/database/app_database.dart';
import 'package:delivery_app/core/domain/value_objects/coordinate.dart';
import 'package:delivery_app/features/drivers/domain/entities/driver.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/availability_status.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/driver_status.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/vehicle_info.dart';
import 'package:delivery_app/features/drivers/domain/value_objects/vehicle_type.dart';

/// [DriverMapper] - Data mapper for converting between Driver representations
///
/// **What it does:**
/// - Converts Driver domain entity to/from database models (DriverTableData)
/// - Converts Driver domain entity to/from backend JSON
/// - Maps vehicle information between formats
/// - Parses enum values (VehicleType, DriverStatus, AvailabilityStatus)
/// - Handles nullable fields and default values
/// - Provides bidirectional mapping (entity ↔ database ↔ backend)
///
/// **Why it exists:**
/// - Separates domain entities from data layer models (Clean Architecture)
/// - Enables data format changes without affecting domain layer
/// - Centralizes conversion logic in one place
/// - Handles different data representations (database snake_case vs domain camelCase)
/// - Makes mapping testable (unit test each conversion)
/// - Prevents coupling between domain and data layers
///
/// **Architecture (Data Mapping Layer):**
/// ```
/// Domain Layer (Business Logic)
///          ↓
/// Driver Entity (domain model)
///   ↕ (DriverMapper)
/// Data Layer
///   ├─ DriverTableData (Drift/SQLite model)
///   └─ Backend JSON (REST API format)
/// ```
///
/// **Mapping Flow (Backend → Domain → Database):**
/// ```
/// Backend API Response:
/// {
///   "id": "drv_123",
///   "user_id": "usr_456",
///   "first_name": "Amaka",
///   "last_name": "Nwosu",
///   "email": "amaka@example.com",
///   "phone_number": "+2348098765432",
///   "license_number": "LAG-67890-XY",
///   "vehicle": {
///     "plate": "ABC-123-XY",
///     "type": "motorcycle",
///     "make": "Honda",
///     "model": "CB500X",
///     "year": 2023,
///     "color": "Red"
///   },
///   "status": "approved",
///   "availability": "available",
///   "current_latitude": 6.5244,
///   "current_longitude": 3.3792,
///   "rating": 4.8,
///   "total_ratings": 150
/// }
///       ↓ fromBackendJson()
/// Driver Entity (domain):
/// Driver(
///   id: 'drv_123',
///   userId: 'usr_456',
///   firstName: 'Amaka',
///   lastName: 'Nwosu',
///   vehicleInfo: VehicleInfo(...),
///   status: DriverStatus.approved,
///   availability: AvailabilityStatus.available,
///   currentLocation: Coordinate(6.5244, 3.3792),
///   rating: 4.8,
///   totalRatings: 150,
/// )
///       ↓ toDatabase()
/// DriverTableData (database):
/// DriverTableData(
///   id: 'drv_123',
///   userId: 'usr_456',
///   firstName: 'Amaka',
///   lastName: 'Nwosu',
///   vehiclePlate: 'ABC-123-XY',
///   vehicleType: 'motorcycle',
///   vehicleMake: 'Honda',
///   vehicleModel: 'CB500X',
///   vehicleYear: 2023,
///   vehicleColor: 'Red',
///   status: 'approved',
///   availability: 'available',
///   currentLatitude: 6.5244,
///   currentLongitude: 3.3792,
///   rating: 4.8,
///   totalRatings: 150,
/// )
/// ```
///
/// **Key Conversions:**
/// ```
/// 1. Backend JSON → Domain Entity (fromBackendJson):
///    - Extracts nested vehicle object
///    - Parses enum strings to enum types
///    - Converts snake_case to camelCase
///    - Handles nullable location (lat/lng)
///    - Parses ISO 8601 timestamps
///    - Provides default values for missing fields
///
/// 2. Domain Entity → Database Model (toDatabase):
///    - Flattens vehicle object to columns
///    - Converts enums to string names
///    - Extracts coordinate lat/lng to separate columns
///    - Preserves all domain fields
///    - Sets lastSyncedAt to null (managed by sync worker)
///
/// 3. Database Model → Domain Entity (fromDatabase):
///    - Reconstructs vehicle object from columns
///    - Parses enum strings to enum types
///    - Reconstructs Coordinate from lat/lng
///    - Handles nullable fields gracefully
/// ```
///
/// **Usage Example:**
/// ```dart
/// // Backend → Domain
/// final json = response.data['data'] as Map<String, dynamic>;
/// final driver = DriverMapper.fromBackendJson(json);
///
/// // Domain → Database
/// final driver = Driver(...);
/// final driverData = DriverMapper.toDatabase(driver);
/// await database.driverDao.upsertDriver(driverData);
///
/// // Database → Domain
/// final driverData = await database.driverDao.getDriverById(id);
/// final driver = DriverMapper.fromDatabase(driverData);
/// ```
///
/// **IMPROVEMENTS:**
/// - [High Priority] Add toBackendJson() for PUT/POST requests
/// - Currently only fromBackendJson exists
/// - [Medium Priority] Add validation during mapping
/// - Validate email format, phone format, license format
/// - [Medium Priority] Add error handling for malformed data
/// - Currently assumes valid input, may crash on bad data
/// - [Low Priority] Add mapper for partial updates (PATCH)
/// - Support updating only changed fields
/// - [Low Priority] Add mapper performance metrics
/// - Track conversion times for optimization
class DriverMapper {
  /// Converts database model to domain entity
  ///
  /// **What it does:**
  /// - Maps DriverTableData (Drift database model) to Driver (domain entity)
  /// - Reconstructs VehicleInfo from flattened vehicle columns
  /// - Reconstructs Coordinate from latitude/longitude columns
  /// - Parses enum strings to enum types
  /// - Handles nullable location and timestamps
  ///
  /// **Flow:**
  /// ```
  /// DriverTableData (database)
  ///       ↓
  /// Extract vehicle columns → VehicleInfo value object
  ///       ↓
  /// Parse vehicleType string → VehicleType enum
  ///       ↓
  /// Extract lat/lng → Coordinate (if both exist)
  ///       ↓
  /// Parse status string → DriverStatus enum
  ///       ↓
  /// Parse availability string → AvailabilityStatus enum
  ///       ↓
  /// Assemble Driver entity
  /// ```
  ///
  /// **Parameters:**
  /// - [data]: DriverTableData from Drift database query
  ///
  /// **Returns:**
  /// - Driver entity with reconstructed value objects
  ///
  /// **Example:**
  /// ```dart
  /// final driverData = await database.driverDao.getDriverById('drv_123');
  /// final driver = DriverMapper.fromDatabase(driverData);
  /// print('${driver.fullName} drives ${driver.vehicleInfo.make} ${driver.vehicleInfo.model}');
  /// ```
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
        rejectionReason: data.rejectionReason,
        suspensionReason: data.suspensionReason,
        suspensionExpiresAt: data.suspensionExpiresAt,
        statusUpdatedAt: data.statusUpdatedAt,
      );

  /// Converts backend JSON response to domain entity
  ///
  /// **What it does:**
  /// - Maps backend REST API JSON to Driver entity
  /// - Extracts nested vehicle object → VehicleInfo
  /// - Converts snake_case field names to camelCase
  /// - Parses enum strings to enum types
  /// - Handles nullable location coordinates
  /// - Parses ISO 8601 timestamp strings to DateTime
  /// - Provides sensible defaults for missing fields
  ///
  /// **Flow:**
  /// ```
  /// Backend JSON Response
  ///       ↓
  /// Extract 'vehicle' nested object
  ///       ↓
  /// Create VehicleInfo(
  ///   plate: vehicle['plate'],
  ///   type: parseVehicleType(vehicle['type']),
  ///   make: vehicle['make'],
  ///   ...
  /// )
  ///       ↓
  /// Parse status string → DriverStatus enum
  ///       ↓
  /// Parse availability string → AvailabilityStatus enum
  ///       ↓
  /// Check lat/lng exist → Create Coordinate or null
  ///       ↓
  /// Parse timestamp strings → DateTime or null
  ///       ↓
  /// Assemble Driver entity
  /// ```
  ///
  /// **Backend JSON Format:**
  /// ```json
  /// {
  ///   "id": "drv_123",
  ///   "user_id": "usr_456",
  ///   "first_name": "Amaka",
  ///   "last_name": "Nwosu",
  ///   "email": "amaka@example.com",
  ///   "phone_number": "+2348098765432",
  ///   "license_number": "LAG-67890-XY",
  ///   "vehicle": {
  ///     "plate": "ABC-123-XY",
  ///     "type": "motorcycle",
  ///     "make": "Honda",
  ///     "model": "CB500X",
  ///     "year": 2023,
  ///     "color": "Red"
  ///   },
  ///   "status": "approved",
  ///   "availability": "available",
  ///   "current_latitude": 6.5244,
  ///   "current_longitude": 3.3792,
  ///   "last_location_update": "2025-10-04T14:30:00Z",
  ///   "rating": 4.8,
  ///   "total_ratings": 150,
  ///   "rejection_reason": null,
  ///   "suspension_reason": null,
  ///   "suspension_expires_at": null,
  ///   "status_updated_at": "2025-10-01T10:00:00Z"
  /// }
  /// ```
  ///
  /// **Default Values:**
  /// - vehicle.plate → '' (empty string)
  /// - vehicle.type → 'car' (fallback)
  /// - vehicle.make → '' (empty string)
  /// - vehicle.model → '' (empty string)
  /// - vehicle.year → current year
  /// - vehicle.color → '' (empty string)
  /// - availability → 'offline' (fallback)
  /// - rating → 0.0
  /// - total_ratings → 0
  ///
  /// **Parameters:**
  /// - [json]: Backend API response data (already extracted from wrapper)
  ///
  /// **Returns:**
  /// - Driver entity with all fields populated
  ///
  /// **Example:**
  /// ```dart
  /// final response = await apiClient.get('/drivers/usr_456');
  /// final data = response.data['data'] as Map<String, dynamic>;
  /// final driver = DriverMapper.fromBackendJson(data);
  /// print('${driver.fullName} - Status: ${driver.status.name}');
  /// ```
  static Driver fromBackendJson(Map<String, dynamic> json) {
    final vehicle = json['vehicle'] as Map<String, dynamic>?;

    return Driver(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      email: json['email'] as String,
      phone: json['phone_number'] as String,
      licenseNumber: json['license_number'] as String,
      vehicleInfo: VehicleInfo(
        plate: vehicle?['plate'] as String? ?? '',
        type: _parseVehicleType(vehicle?['type'] as String? ?? 'car'),
        make: vehicle?['make'] as String? ?? '',
        model: vehicle?['model'] as String? ?? '',
        year: vehicle?['year'] as int? ?? DateTime.now().year,
        color: vehicle?['color'] as String? ?? '',
      ),
      status: _parseDriverStatus(json['status'] as String),
      availability: _parseAvailabilityStatus(
          json['availability'] as String? ?? 'offline'),
      currentLocation: json['current_latitude'] != null &&
              json['current_longitude'] != null
          ? Coordinate(
              latitude: (json['current_latitude'] as num).toDouble(),
              longitude: (json['current_longitude'] as num).toDouble(),
            )
          : null,
      lastLocationUpdate: json['last_location_update'] != null
          ? DateTime.parse(json['last_location_update'] as String)
          : null,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalRatings: json['total_ratings'] as int? ?? 0,
      rejectionReason: json['rejection_reason'] as String?,
      suspensionReason: json['suspension_reason'] as String?,
      suspensionExpiresAt: json['suspension_expires_at'] != null
          ? DateTime.parse(json['suspension_expires_at'] as String)
          : null,
      statusUpdatedAt: json['status_updated_at'] != null
          ? DateTime.parse(json['status_updated_at'] as String)
          : null,
    );
  }

  /// Converts domain entity to database model
  ///
  /// **What it does:**
  /// - Maps Driver entity to DriverTableData (Drift database model)
  /// - Flattens VehicleInfo object into separate columns
  /// - Converts enums to string names
  /// - Extracts Coordinate lat/lng into separate columns
  /// - Preserves all domain fields for storage
  /// - Sets lastSyncedAt to null (managed by sync worker)
  ///
  /// **Flow:**
  /// ```
  /// Driver Entity
  ///       ↓
  /// Extract VehicleInfo fields → vehicle columns
  ///   ├─ vehiclePlate: vehicleInfo.plate
  ///   ├─ vehicleType: vehicleInfo.type.name
  ///   ├─ vehicleMake: vehicleInfo.make
  ///   ├─ vehicleModel: vehicleInfo.model
  ///   ├─ vehicleYear: vehicleInfo.year
  ///   └─ vehicleColor: vehicleInfo.color
  ///       ↓
  /// Convert enums to strings
  ///   ├─ status: driver.status.name
  ///   └─ availability: driver.availability.name
  ///       ↓
  /// Extract Coordinate lat/lng
  ///   ├─ currentLatitude: location?.latitude
  ///   └─ currentLongitude: location?.longitude
  ///       ↓
  /// Assemble DriverTableData
  /// ```
  ///
  /// **Column Mapping:**
  /// ```
  /// Domain Entity Field → Database Column
  /// ==========================================
  /// driver.id → id
  /// driver.userId → userId
  /// driver.firstName → firstName
  /// driver.lastName → lastName
  /// driver.email → email
  /// driver.phone → phone
  /// driver.licenseNumber → licenseNumber
  /// driver.vehicleInfo.plate → vehiclePlate
  /// driver.vehicleInfo.type.name → vehicleType
  /// driver.vehicleInfo.make → vehicleMake
  /// driver.vehicleInfo.model → vehicleModel
  /// driver.vehicleInfo.year → vehicleYear
  /// driver.vehicleInfo.color → vehicleColor
  /// driver.status.name → status
  /// driver.availability.name → availability
  /// driver.currentLocation?.latitude → currentLatitude
  /// driver.currentLocation?.longitude → currentLongitude
  /// driver.lastLocationUpdate → lastLocationUpdate
  /// driver.rating → rating
  /// driver.totalRatings → totalRatings
  /// driver.rejectionReason → rejectionReason
  /// driver.suspensionReason → suspensionReason
  /// driver.suspensionExpiresAt → suspensionExpiresAt
  /// driver.statusUpdatedAt → statusUpdatedAt
  /// null → lastSyncedAt (managed by sync worker)
  /// ```
  ///
  /// **Parameters:**
  /// - [driver]: Driver entity to convert
  ///
  /// **Returns:**
  /// - DriverTableData ready for database insertion/update
  ///
  /// **Example:**
  /// ```dart
  /// final driver = Driver(
  ///   id: 'drv_123',
  ///   userId: 'usr_456',
  ///   firstName: 'Amaka',
  ///   lastName: 'Nwosu',
  ///   vehicleInfo: VehicleInfo(
  ///     plate: 'ABC-123-XY',
  ///     type: VehicleType.motorcycle,
  ///     make: 'Honda',
  ///     model: 'CB500X',
  ///     year: 2023,
  ///     color: 'Red',
  ///   ),
  ///   status: DriverStatus.approved,
  ///   availability: AvailabilityStatus.available,
  ///   currentLocation: Coordinate(6.5244, 3.3792),
  ///   rating: 4.8,
  ///   totalRatings: 150,
  /// );
  ///
  /// final driverData = DriverMapper.toDatabase(driver);
  /// await database.driverDao.upsertDriver(driverData);
  /// ```
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
        rejectionReason: driver.rejectionReason,
        suspensionReason: driver.suspensionReason,
        suspensionExpiresAt: driver.suspensionExpiresAt,
        statusUpdatedAt: driver.statusUpdatedAt,
        lastSyncedAt: null,
      );

  /// Parses vehicle type string to enum
  ///
  /// **What it does:**
  /// - Converts string vehicle type to VehicleType enum
  /// - Case-insensitive matching (converts to lowercase)
  /// - Provides fallback default (motorcycle) for unknown types
  ///
  /// **Supported Types:**
  /// - 'motorcycle' → VehicleType.motorcycle
  /// - 'car' → VehicleType.car
  /// - 'van' → VehicleType.van
  /// - 'bicycle' → VehicleType.bicycle
  /// - unknown → VehicleType.motorcycle (fallback)
  ///
  /// **Parameters:**
  /// - [type]: Vehicle type string from backend/database
  ///
  /// **Returns:**
  /// - VehicleType enum value
  ///
  /// **Example:**
  /// ```dart
  /// final type = _parseVehicleType('MOTORCYCLE'); // VehicleType.motorcycle
  /// final fallback = _parseVehicleType('scooter'); // VehicleType.motorcycle (fallback)
  /// ```
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

  /// Parses driver status string to enum
  ///
  /// **What it does:**
  /// - Converts string driver status to DriverStatus enum
  /// - Case-insensitive matching (converts to lowercase)
  /// - Provides fallback default (pending) for unknown statuses
  ///
  /// **Supported Statuses:**
  /// - 'pending' → DriverStatus.pending (awaiting admin approval)
  /// - 'approved' → DriverStatus.approved (verified, can accept orders)
  /// - 'rejected' → DriverStatus.rejected (application denied)
  /// - 'suspended' → DriverStatus.suspended (temporarily blocked)
  /// - unknown → DriverStatus.pending (fallback)
  ///
  /// **Parameters:**
  /// - [status]: Driver status string from backend/database
  ///
  /// **Returns:**
  /// - DriverStatus enum value
  ///
  /// **Example:**
  /// ```dart
  /// final status = _parseDriverStatus('APPROVED'); // DriverStatus.approved
  /// final fallback = _parseDriverStatus('active'); // DriverStatus.pending (fallback)
  /// ```
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

  /// Parses availability status string to enum
  ///
  /// **What it does:**
  /// - Converts string availability to AvailabilityStatus enum
  /// - Case-insensitive matching (converts to lowercase)
  /// - Provides fallback default (offline) for unknown statuses
  ///
  /// **Supported Statuses:**
  /// - 'offline' → AvailabilityStatus.offline (not working, can't accept orders)
  /// - 'available' → AvailabilityStatus.available (online, ready for orders)
  /// - 'busy' → AvailabilityStatus.busy (currently handling order)
  /// - unknown → AvailabilityStatus.offline (fallback)
  ///
  /// **Parameters:**
  /// - [availability]: Availability status string from backend/database
  ///
  /// **Returns:**
  /// - AvailabilityStatus enum value
  ///
  /// **Example:**
  /// ```dart
  /// final status = _parseAvailabilityStatus('AVAILABLE'); // AvailabilityStatus.available
  /// final fallback = _parseAvailabilityStatus('online'); // AvailabilityStatus.offline (fallback)
  /// ```
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
