import 'package:delivery_app/core/database/app_database.dart';

/// Extension methods for OrderTableData to support sync operations
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

/// Extension methods for OrderItemTableData
extension OrderItemTableDataExtensions on OrderItemTableData {
  /// Converts OrderItemTableData to JSON map
  Map<String, dynamic> toJsonMap() => {
        'category': category,
        'description': description,
        'weight': weight,
        'size': size,
      };
}
