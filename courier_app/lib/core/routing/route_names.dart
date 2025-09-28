/// Route names for the application
class RouteNames {
  // Auth Routes
  static const String splash = 'splash';
  static const String login = 'login';
  static const String register = 'register';
  static const String forgotPassword = 'forgot-password';
  static const String resetPassword = 'reset-password';
  static const String verifyEmail = 'verify-email';

  // Customer Routes
  static const String customerHome = 'customer-home';
  static const String customerProfile = 'customer-profile';
  static const String customerOrders = 'customer-orders';
  static const String customerOrderDetails = 'customer-order-details';
  static const String customerCreateOrder = 'customer-create-order';
  static const String customerTrackOrder = 'customer-track-order';
  static const String customerPayment = 'customer-payment';
  static const String customerAddresses = 'customer-addresses';
  static const String customerNotifications = 'customer-notifications';

  // Driver Routes
  static const String driverHome = 'driver-home';
  static const String driverOnboarding = 'driver-onboarding';
  static const String driverProfile = 'driver-profile';
  static const String driverDeliveries = 'driver-deliveries';
  static const String driverDeliveryDetails = 'driver-delivery-details';
  static const String driverEarnings = 'driver-earnings';
  static const String driverVehicle = 'driver-vehicle';
  static const String driverDocuments = 'driver-documents';
  static const String driverNotifications = 'driver-notifications';
  static const String driverNavigation = 'driver-navigation';

  // Common Routes
  static const String settings = 'settings';
  static const String support = 'support';
  static const String about = 'about';
  static const String termsAndConditions = 'terms-and-conditions';
  static const String privacyPolicy = 'privacy-policy';
}

/// Route paths for the application
class RoutePaths {
  // Auth Paths
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password/:token';
  static const String verifyEmail = '/verify-email/:code';

  // Customer Paths
  static const String customerHome = '/customer/home';
  static const String customerProfile = '/customer/profile';
  static const String customerOrders = '/customer/orders';
  static const String customerOrderDetails = '/customer/orders/:orderId';
  static const String customerCreateOrder = '/customer/orders/create';
  static const String customerTrackOrder = '/customer/orders/:orderId/track';
  static const String customerPayment = '/customer/payment';
  static const String customerAddresses = '/customer/addresses';
  static const String customerNotifications = '/customer/notifications';

  // Driver Paths
  static const String driverHome = '/driver/home';
  static const String driverOnboarding = '/driver/onboarding';
  static const String driverProfile = '/driver/profile';
  static const String driverDeliveries = '/driver/deliveries';
  static const String driverDeliveryDetails = '/driver/deliveries/:deliveryId';
  static const String driverEarnings = '/driver/earnings';
  static const String driverVehicle = '/driver/vehicle';
  static const String driverDocuments = '/driver/documents';
  static const String driverNotifications = '/driver/notifications';
  static const String driverNavigation = '/driver/navigation/:deliveryId';

  // Common Paths
  static const String settings = '/settings';
  static const String support = '/support';
  static const String about = '/about';
  static const String termsAndConditions = '/terms-and-conditions';
  static const String privacyPolicy = '/privacy-policy';
}