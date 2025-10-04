import 'package:delivery_app/core/error/exceptions.dart';
import 'package:delivery_app/core/network/api_client.dart';
import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:delivery_app/shared/models/user_model.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// [AuthRemoteDataSource] - Abstract interface for authentication remote data operations
///
/// **Contract Definition:**
/// Defines operations for interacting with authentication backend APIs.
/// Implementations handle HTTP communication and error transformation.
abstract class AuthRemoteDataSource {
  /// Authenticates a user with email and password
  Future<UserModel> login({
    required String email,
    required String password,
  });

  /// Registers a new user
  Future<UserModel> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    required String role,
  });

  /// Gets the current user profile
  Future<UserModel> getCurrentUser();

  /// Refreshes the authentication token
  Future<Map<String, dynamic>> refreshToken(String refreshToken);

  /// Sends password reset email
  Future<void> sendPasswordResetEmail(String email);

  /// Verifies email with verification code
  Future<void> verifyEmail(String verificationCode);

  /// Changes user password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Updates user profile
  Future<UserModel> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
  });

  /// Logs out the current user
  Future<void> logout(String? refreshToken);

  /// Gets CSRF token for write operations
  Future<String> getCsrfToken();
}

/// [AuthRemoteDataSourceImpl] - Backend API client for authentication operations
///
/// **What it does:**
/// - Handles all authentication-related HTTP requests to backend
/// - Transforms backend responses into domain models (UserModel)
/// - Converts HTTP/network errors to domain exceptions
/// - Manages CSRF token retrieval for write operations
/// - Handles token-based authentication headers
/// - Provides automatic login after registration
///
/// **Why it exists:**
/// - Isolates HTTP communication from business logic
/// - Centralizes API endpoint definitions
/// - Standardizes error handling across auth operations
/// - Enables easy mocking for testing
/// - Separates data layer concerns from domain layer
/// - Provides clean abstraction over Dio HTTP client
///
/// **Architecture:**
/// ```
/// AuthRepository
///       ↓
/// AuthRemoteDataSource ← YOU ARE HERE
///       ↓
/// ApiClient (Dio wrapper)
///       ↓
/// Backend REST API
/// ```
///
/// **API Endpoints:**
/// ```
/// POST   /users/auth              - Login with email/password
/// POST   /users                   - Register new user
/// GET    /users/me                - Get current user profile
/// POST   /users/refresh           - Refresh access token
/// PATCH  /users/me                - Update user profile
/// POST   /auth/password/reset     - Send password reset email
/// POST   /auth/email/verify       - Verify email with code
/// POST   /auth/password/change    - Change password
/// POST   /auth/logout             - Logout (revoke tokens)
/// GET    /auth/csrf               - Get CSRF token
/// ```
///
/// **Authentication Flow:**
/// ```
/// login(email, password)
///       ↓
/// POST /users/auth
///   ├─ Request: { email, password }
///   └─ Headers: Content-Type: application/json
///       ↓
/// Backend validates credentials
///       ↓
/// Response: {
///   data: {
///     user_id, email, name, role, token
///   }
/// }
///       ↓
/// Parse name → firstName, lastName
///       ↓
/// Create UserModel with tokens
///       ↓
/// Return to repository
/// ```
///
/// **Error Handling Strategy:**
/// ```
/// Dio Request
///       ↓
/// DioException thrown?
///   ↙             ↘
///  YES            NO
///   ↓              ↓
/// Check status   Parse response
///   ↓              ↓
/// 401 → AuthenticationException
/// 409 → ServerException (duplicate)
/// 400 → ValidationException
/// Timeout → ServerException
/// No connection → NetworkException
///   ↓
/// Throw domain exception
/// ```
///
/// **Response Parsing:**
/// - Backend returns nested data under 'data' key
/// - Name field split into firstName/lastName
/// - Missing phone number filled with placeholder (TODO: fix backend)
/// - Timestamps created for created_at/updated_at if missing
///
/// **Usage Example:**
/// ```dart
/// final remoteDataSource = AuthRemoteDataSourceImpl(
///   apiClient: ApiClient(),
/// );
///
/// try {
///   // Login
///   final user = await remoteDataSource.login(
///     email: 'user@example.com',
///     password: 'password123',
///   );
///   print('Logged in: ${user.email}');
///
///   // Get current user
///   final currentUser = await remoteDataSource.getCurrentUser();
///
///   // Update profile with CSRF protection
///   final updatedUser = await remoteDataSource.updateProfile(
///     firstName: 'John',
///     lastName: 'Doe',
///   );
/// } on ServerException catch (e) {
///   print('Server error: ${e.message}');
/// } on NetworkException catch (e) {
///   print('Network error: ${e.message}');
/// }
/// ```
///
/// **IMPROVEMENTS:**
/// - [High Priority] Backend should return phone number in login response
///   - Currently using placeholder '+2340000000000'
/// - [High Priority] Backend should return refresh_token in login response
///   - Currently using empty string placeholder
/// - [High Priority] Backend should return csrf_token in login response
///   - Currently using empty string placeholder
/// - [Medium Priority] Add request/response logging interceptor
///   - Helpful for debugging API issues
/// - [Medium Priority] Add retry logic for transient network failures
///   - Currently fails immediately on network error
/// - [Medium Priority] Extract endpoint URLs to constants file
///   - Enables environment-specific URLs (dev, staging, prod)
/// - [Low Priority] Add request timeout configuration per endpoint
///   - Some operations (like registration) may need longer timeout
/// - [Low Priority] Add response validation (schema checking)
///   - Detect when backend changes response structure
@LazySingleton(as: AuthRemoteDataSource)
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient _apiClient;

  // API Endpoints (aligned with backend)
  static const String _loginEndpoint = '/users/auth';
  static const String _registerEndpoint = '/users';
  static const String _logoutEndpoint = '/auth/logout';
  static const String _refreshTokenEndpoint = '/users/refresh';
  static const String _currentUserEndpoint = '/users/me';
  static const String _updateProfileEndpoint = '/users/me';
  static const String _passwordResetEndpoint = '/auth/password/reset';
  static const String _verifyEmailEndpoint = '/auth/email/verify';
  static const String _changePasswordEndpoint = '/auth/password/change';
  static const String _csrfTokenEndpoint = '/auth/csrf';

  AuthRemoteDataSourceImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  /// Authenticates user with email and password via backend API
  ///
  /// **What it does:**
  /// 1. Sends POST request to /users/auth with credentials
  /// 2. Validates response status (200 = success)
  /// 3. Extracts user data from nested 'data' object
  /// 4. Parses full name into firstName and lastName
  /// 5. Creates UserModel with access token
  /// 6. Returns authenticated user model
  ///
  /// **Backend Response Format:**
  /// ```json
  /// {
  ///   "data": {
  ///     "user_id": "123",
  ///     "email": "user@example.com",
  ///     "name": "John Doe",
  ///     "role": "customer",
  ///     "token": "eyJhbGc..."
  ///   }
  /// }
  /// ```
  ///
  /// **Name Parsing Logic:**
  /// - "John Doe" → firstName: "John", lastName: "Doe"
  /// - "John" → firstName: "John", lastName: ""
  /// - "John Middle Doe" → firstName: "John", lastName: "Middle Doe"
  ///
  /// **Throws:**
  /// - ServerException: Invalid credentials (401), server error, or unexpected response
  /// - NetworkException: Connection timeout or no internet
  ///
  /// **Edge Cases:**
  /// - 401 Unauthorized → "Invalid credentials" message
  /// - Connection timeout → "Connection timeout" message
  /// - No internet → "No internet connection" message
  /// - Non-200 response → Uses backend message or generic error
  ///
  /// **IMPROVEMENT:**
  /// - [High Priority] Backend should return structured firstName/lastName
  ///   - Current name parsing is fragile
  /// - [Medium Priority] Add input validation before API call
  ///   - Check email format, password length
  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post(
        _loginEndpoint,
        data: {
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        // Backend returns data directly under 'data' key
        final responseData = response.data['data'];

        // Parse the name field to get first and last names
        final fullName = responseData['name'] ?? '';
        final nameParts = fullName.split(' ');
        final firstName = nameParts.isNotEmpty ? nameParts.first : '';
        final lastName =
            nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

        // Create user data structure expected by UserModel
        final userData = {
          'id': responseData['user_id'],
          'email': responseData['email'],
          'first_name': firstName,
          'last_name': lastName,
          // TODO: Backend should return phone number in login response
          'phone':
              '+2340000000000', // Placeholder - backend doesn't provide phone in login response
          'role': responseData['role'],
          'status': 'active',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          // Add token data
          'access_token': responseData['token'],
          // TODO: Backend should return refresh_token in login response
          'refresh_token':
              '', // Placeholder - backend doesn't provide refresh token yet
          // TODO: Backend should return csrf_token in login response
          'csrf_token':
              '', // Placeholder - backend doesn't provide CSRF token yet
        };

        return UserModel.fromJson(userData);
      } else {
        throw ServerException(
          message: response.data['message'] ?? AppStrings.errorLoginFailed,
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const ServerException(
          message: AppStrings.errorInvalidCredentials,
        );
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw const ServerException(
          message: AppStrings.errorConnectionTimeout,
        );
      } else if (e.type == DioExceptionType.connectionError) {
        throw const ServerException(
          message: AppStrings.errorNoInternet,
        );
      } else {
        throw ServerException(
          message: e.response?.data['message'] ?? AppStrings.errorLoginFailed,
        );
      }
    } catch (e) {
      throw ServerException(
        message: e.toString(),
      );
    }
  }

  /// Registers new user and automatically logs them in
  ///
  /// **What it does:**
  /// 1. Sends POST request to /users with registration data
  /// 2. Validates response status (201 = created)
  /// 3. Automatically calls login() to get access token
  /// 4. Returns fully authenticated UserModel
  ///
  /// **Why auto-login:**
  /// - Backend registration doesn't return tokens
  /// - User expects to be logged in after registration
  /// - Prevents extra manual login step
  ///
  /// **Flow Diagram:**
  /// ```
  /// register()
  ///       ↓
  /// POST /users
  ///   ├─ first_name
  ///   ├─ last_name
  ///   ├─ email
  ///   ├─ phone
  ///   ├─ password
  ///   └─ role
  ///       ↓
  /// 201 Created
  ///       ↓
  /// Automatically login(email, password)
  ///       ↓
  /// Return UserModel with tokens
  /// ```
  ///
  /// **Throws:**
  /// - ServerException: Email/phone already exists (409), validation failed (400)
  /// - NetworkException: Connection error
  ///
  /// **Edge Cases:**
  /// - 409 Conflict + "email" in message → "Email already exists"
  /// - 409 Conflict + "phone" in message → "Phone already exists"
  /// - 400 Bad Request → Validation error message
  /// - Auto-login fails → Throws login error
  ///
  /// **IMPROVEMENT:**
  /// - [Medium Priority] Return specific field validation errors
  ///   - Backend should specify which field failed
  /// - [Low Priority] Skip auto-login if email verification required
  @override
  Future<UserModel> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    required String role,
  }) async {
    try {
      final response = await _apiClient.post(
        _registerEndpoint,
        data: {
          'first_name': firstName,
          'last_name': lastName,
          'email': email,
          'phone': phone,
          'password': password,
          'role': role,
        },
      );

      if (response.statusCode == 201) {
        // Registration successful, but backend doesn't return tokens
        // Automatically login to get tokens and complete user data
        return await login(email: email, password: password);
      } else {
        throw ServerException(
          message:
              response.data['message'] ?? AppStrings.errorRegistrationFailed,
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        final message = e.response?.data['message'] ?? '';
        if (message.contains('email')) {
          throw const ServerException(
            message: AppStrings.errorEmailAlreadyExists,
          );
        } else if (message.contains('phone')) {
          throw const ServerException(
            message: AppStrings.errorPhoneAlreadyExists,
          );
        }
      } else if (e.response?.statusCode == 400) {
        throw ServerException(
          message:
              e.response?.data['message'] ?? AppStrings.errorValidationFailed,
        );
      }
      throw ServerException(
        message:
            e.response?.data['message'] ?? AppStrings.errorRegistrationFailed,
      );
    } catch (e) {
      throw ServerException(
        message: e.toString(),
      );
    }
  }

  @override
  Future<UserModel> getCurrentUser() async {
    try {
      final response = await _apiClient.get(_currentUserEndpoint);

      if (response.statusCode == 200) {
        return UserModel.fromJson(response.data['user']);
      } else {
        throw ServerException(
          message: response.data['message'] ?? AppStrings.errorUserNotFound,
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const ServerException(
          message: AppStrings.errorSessionExpired,
        );
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw const ServerException(
          message: AppStrings.errorConnectionTimeout,
        );
      } else if (e.type == DioExceptionType.connectionError) {
        throw const ServerException(
          message: AppStrings.errorNoInternet,
        );
      } else {
        throw ServerException(
          message: e.response?.data['message'] ?? AppStrings.errorUnknown,
        );
      }
    } catch (e) {
      throw ServerException(
        message: e.toString(),
      );
    }
  }

  @override
  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    try {
      final response = await _apiClient.post(
        _refreshTokenEndpoint,
        data: {
          'refresh_token': refreshToken,
        },
      );

      if (response.statusCode == 200) {
        return {
          'access_token': response.data['access_token'],
          'refresh_token': response.data['refresh_token'],
          'csrf_token': response.data['csrf_token'],
        };
      } else {
        throw ServerException(
          message:
              response.data['message'] ?? AppStrings.errorTokenRefreshFailed,
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const ServerException(
          message: AppStrings.errorInvalidRefreshToken,
        );
      }
      throw ServerException(
        message:
            e.response?.data['message'] ?? AppStrings.errorTokenRefreshFailed,
      );
    } catch (e) {
      throw ServerException(
        message: e.toString(),
      );
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      final response = await _apiClient.post(
        _passwordResetEndpoint,
        data: {
          'email': email,
        },
      );

      if (response.statusCode != 200) {
        throw ServerException(
          message: response.data['message'] ?? AppStrings.errorUnknown,
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const ServerException(
          message: AppStrings.errorUserNotFound,
        );
      }
      throw ServerException(
        message: e.response?.data['message'] ?? AppStrings.errorUnknown,
      );
    } catch (e) {
      throw ServerException(
        message: e.toString(),
      );
    }
  }

  @override
  Future<void> verifyEmail(String verificationCode) async {
    try {
      final response = await _apiClient.post(
        _verifyEmailEndpoint,
        data: {
          'code': verificationCode,
        },
      );

      if (response.statusCode != 200) {
        throw ServerException(
          message: response.data['message'] ?? AppStrings.errorUnknown,
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw const ServerException(
          message: AppStrings.errorInvalidInput,
        );
      }
      throw ServerException(
        message: e.response?.data['message'] ?? AppStrings.errorUnknown,
      );
    } catch (e) {
      throw ServerException(
        message: e.toString(),
      );
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      // Get CSRF token for write operation
      final csrfToken = await getCsrfToken();

      final response = await _apiClient.post(
        _changePasswordEndpoint,
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
        options: Options(
          headers: {
            'X-CSRF-Token': csrfToken,
          },
        ),
      );

      if (response.statusCode != 200) {
        throw ServerException(
          message: response.data['message'] ?? AppStrings.errorUnknown,
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const ServerException(
          message: AppStrings.errorInvalidCredentials,
        );
      } else if (e.response?.statusCode == 400) {
        throw ServerException(
          message: e.response?.data['message'] ?? AppStrings.errorWeakPassword,
        );
      }
      throw ServerException(
        message: e.response?.data['message'] ?? AppStrings.errorUnknown,
      );
    } catch (e) {
      throw ServerException(
        message: e.toString(),
      );
    }
  }

  @override
  Future<UserModel> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
  }) async {
    try {
      // Get CSRF token for write operation
      final csrfToken = await getCsrfToken();

      final data = <String, dynamic>{};
      if (firstName != null) data['first_name'] = firstName;
      if (lastName != null) data['last_name'] = lastName;
      if (phone != null) data['phone'] = phone;

      final response = await _apiClient.patch(
        _updateProfileEndpoint,
        data: data,
        options: Options(
          headers: {
            'X-CSRF-Token': csrfToken,
          },
        ),
      );

      if (response.statusCode == 200) {
        return UserModel.fromJson(response.data['user']);
      } else {
        throw ServerException(
          message: response.data['message'] ?? AppStrings.errorUnknown,
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const ServerException(
          message: AppStrings.errorSessionExpired,
        );
      } else if (e.response?.statusCode == 400) {
        throw ServerException(
          message:
              e.response?.data['message'] ?? AppStrings.errorValidationFailed,
        );
      }
      throw ServerException(
        message: e.response?.data['message'] ?? AppStrings.errorUnknown,
      );
    } catch (e) {
      throw ServerException(
        message: e.toString(),
      );
    }
  }

  @override
  Future<void> logout(String? refreshToken) async {
    try {
      await _apiClient.post(
        _logoutEndpoint,
        data: refreshToken != null ? {'refresh_token': refreshToken} : null,
      );
    } on DioException catch (_) {
      // Ignore logout errors - we'll clear local data anyway
    } catch (_) {
      // Ignore logout errors - we'll clear local data anyway
    }
  }

  /// Fetches ephemeral CSRF token from backend
  ///
  /// **What it does:**
  /// 1. Sends GET request to /auth/csrf
  /// 2. Extracts csrf_token from response
  /// 3. Returns token string for use in write operations
  ///
  /// **Why CSRF tokens:**
  /// - Protects against Cross-Site Request Forgery attacks
  /// - Required for state-changing operations (POST, PATCH, DELETE)
  /// - Validates request originated from our app
  ///
  /// **Usage in Write Operations:**
  /// - changePassword() includes in X-CSRF-Token header
  /// - updateProfile() includes in X-CSRF-Token header
  /// - Other write operations should include it
  ///
  /// **Throws:**
  /// - ServerException: 401 unauthorized, server error, or missing token in response
  ///
  /// **Example:**
  /// ```dart
  /// final csrfToken = await getCsrfToken();
  /// final response = await apiClient.post(
  ///   '/some/endpoint',
  ///   options: Options(headers: {'X-CSRF-Token': csrfToken}),
  /// );
  /// ```
  ///
  /// **IMPROVEMENT:**
  /// - [Medium Priority] Cache CSRF token with short TTL
  ///   - Reduce API calls for multiple operations
  /// - [Low Priority] Handle CSRF token rotation
  ///   - Backend may invalidate and require new token
  @override
  Future<String> getCsrfToken() async {
    try {
      final response = await _apiClient.get(_csrfTokenEndpoint);

      if (response.statusCode == 200) {
        return response.data['csrf_token'];
      } else {
        throw ServerException(
          message: response.data['message'] ?? AppStrings.errorCsrfTokenFailed,
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const ServerException(
          message: AppStrings.errorSessionExpired,
        );
      }
      throw ServerException(
        message: e.response?.data['message'] ?? AppStrings.errorCsrfTokenFailed,
      );
    } catch (e) {
      throw ServerException(
        message: e.toString(),
      );
    }
  }
}
