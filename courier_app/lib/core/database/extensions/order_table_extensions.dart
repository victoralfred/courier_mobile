import 'package:delivery_app/core/database/app_database.dart';

/// WHAT: Extension methods for OrderTableData database model serialization
///
/// WHY: Provides JSON conversion methods for syncing order data with backend API.
/// Separates serialization logic from table definitions, keeping table files focused
/// on schema. Supports different JSON formats for different API endpoints.
///
/// RESPONSIBILITIES:
/// - Convert OrderTableData to JSON for API requests
/// - Handle nested location objects (pickup/dropoff)
/// - Support different serialization formats (full vs. create)
/// - Include/exclude fields based on operation type
///
/// METHODS:
/// - toJsonMap(): Full order serialization with all fields
/// - toCreateJson(): Minimal payload for order creation (excludes server-generated fields)
///
/// USAGE:
/// ```dart
/// // Full order sync (for updates or fetches)
/// final orderJson = orderData.toJsonMap(item: itemData);
/// // Result: {id, userId, driverId, pickupLocation, dropoffLocation, item, price, status, timestamps}
///
/// // Order creation (excludes id, driverId, timestamps)
/// final createJson = orderData.toCreateJson(item: itemData);
/// // Result: {pickupLocation, dropoffLocation, item, price}
///
/// // Queue for sync
/// await database.syncQueueDao.addToQueue(
///   entityType: 'order',
///   entityId: order.id,
///   operation: 'create',
///   payload: jsonEncode({
///     'endpoint': 'POST /orders',
///     'data': orderData.toCreateJson(item: itemData),
///   }),
/// );
/// ```
///
/// IMPROVEMENT OPPORTUNITIES:
/// - [LOW] Add fromJson() factory method for deserializing API responses
/// - [MEDIUM] Add validation for required fields before serialization
/// - [LOW] Add toUpdateJson() for partial updates (only changed fields)
extension OrderTableDataExtensions on OrderTableData {
  /// Converts OrderTableData to JSON map for API sync
  Map<String, dynamic> toJsonMap({OrderItemTableData? item}) => {
        'id': id,
        'userId': userId,
        if (driverId != null) 'driverId': driverId,
        'pickupLocation': {
          'address': pickupAddress,
          'latitude': pickupLatitude,
          'longitude': pickupLongitude,
          'city': pickupCity,
          'state': pickupState,
          if (pickupPostcode != null) 'postcode': pickupPostcode,
        },
        'dropoffLocation': {
          'address': dropoffAddress,
          'latitude': dropoffLatitude,
          'longitude': dropoffLongitude,
          'city': dropoffCity,
          'state': dropoffState,
          if (dropoffPostcode != null) 'postcode': dropoffPostcode,
        },
        if (item != null)
          'item': {
            'category': item.category,
            'description': item.description,
            'weight': item.weight,
            'size': item.size,
          },
        'price': priceAmount,
        'status': status,
        if (pickupStartedAt != null)
          'pickupStartedAt': pickupStartedAt!.toIso8601String(),
        if (pickupCompletedAt != null)
          'pickupCompletedAt': pickupCompletedAt!.toIso8601String(),
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
        if (cancelledAt != null) 'cancelledAt': cancelledAt!.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// Converts to JSON map for order creation
  Map<String, dynamic> toCreateJson({required OrderItemTableData item}) => {
        'pickupLocation': {
          'address': pickupAddress,
          'latitude': pickupLatitude,
          'longitude': pickupLongitude,
          'city': pickupCity,
          'state': pickupState,
          if (pickupPostcode != null) 'postcode': pickupPostcode,
        },
        'dropoffLocation': {
          'address': dropoffAddress,
          'latitude': dropoffLatitude,
          'longitude': dropoffLongitude,
          'city': dropoffCity,
          'state': dropoffState,
          if (dropoffPostcode != null) 'postcode': dropoffPostcode,
        },
        'item': {
          'category': item.category,
          'description': item.description,
          'weight': item.weight,
          'size': item.size,
        },
        'price': priceAmount,
      };
}

/// WHAT: Extension methods for OrderItemTableData database model serialization
///
/// WHY: Provides JSON conversion for order item data to sync with backend API.
/// Keeps item serialization separate from order serialization for modularity.
///
/// USAGE:
/// ```dart
/// final itemJson = itemData.toJsonMap();
/// // Result: {category, description, weight, size}
/// ```
extension OrderItemTableDataExtensions on OrderItemTableData {
  /// Converts OrderItemTableData to JSON map
  Map<String, dynamic> toJsonMap() => {
        'category': category,
        'description': description,
        'weight': weight,
        'size': size,
      };
}
