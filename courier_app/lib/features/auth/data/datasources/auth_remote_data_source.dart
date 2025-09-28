import 'package:delivery_app/core/error/exceptions.dart';
import 'package:delivery_app/core/network/api_client.dart';
import 'package:delivery_app/core/constants/app_strings.dart';
import 'package:delivery_app/shared/models/user_model.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// Abstract interface for authentication remote data operations
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

/// Implementation of authentication remote data source
@LazySingleton(as: AuthRemoteDataSource)
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient _apiClient;

  // API Endpoints
  static const String _loginEndpoint = '/auth/login';
  static const String _registerEndpoint = '/auth/register';
  static const String _logoutEndpoint = '/auth/logout';
  static const String _refreshTokenEndpoint = '/auth/refresh';
  static const String _currentUserEndpoint = '/users/me';
  static const String _updateProfileEndpoint = '/users/profile';
  static const String _passwordResetEndpoint = '/auth/password/reset';
  static const String _verifyEmailEndpoint = '/auth/email/verify';
  static const String _changePasswordEndpoint = '/auth/password/change';
  static const String _csrfTokenEndpoint = '/auth/csrf';

  AuthRemoteDataSourceImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

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
        final userData = response.data['user'];
        final tokens = response.data['tokens'];

        // Store tokens in the response for the repository to handle
        userData['access_token'] = tokens['access_token'];
        userData['refresh_token'] = tokens['refresh_token'];
        userData['csrf_token'] = tokens['csrf_token'];

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
        final userData = response.data['user'];
        final tokens = response.data['tokens'];

        // Store tokens in the response for the repository to handle
        userData['access_token'] = tokens['access_token'];
        userData['refresh_token'] = tokens['refresh_token'];
        userData['csrf_token'] = tokens['csrf_token'];

        return UserModel.fromJson(userData);
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
          message: e.response?.data['message'] ??
              AppStrings.errorValidationFailed,
        );
      }
      throw ServerException(
        message: e.response?.data['message'] ??
            AppStrings.errorRegistrationFailed,
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

  @override
  Future<String> getCsrfToken() async {
    try {
      final response = await _apiClient.get(_csrfTokenEndpoint);

      if (response.statusCode == 200) {
        return response.data['csrf_token'];
      } else {
        throw ServerException(
          message:
              response.data['message'] ?? AppStrings.errorCsrfTokenFailed,
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const ServerException(
          message: AppStrings.errorSessionExpired,
        );
      }
      throw ServerException(
        message:
            e.response?.data['message'] ?? AppStrings.errorCsrfTokenFailed,
      );
    } catch (e) {
      throw ServerException(
        message: e.toString(),
      );
    }
  }
}