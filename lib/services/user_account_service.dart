import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:school_app/config/config.dart';

class UserAccountResetContext {
  final String email;
  final String userType;
  final bool hasAuthToken;

  const UserAccountResetContext({
    required this.email,
    required this.userType,
    required this.hasAuthToken,
  });
}

class UserAccountException implements Exception {
  final String title;
  final String message;
  final Map<String, String> fieldErrors;

  const UserAccountException({
    required this.title,
    required this.message,
    this.fieldErrors = const {},
  });

  @override
  String toString() => '$title: $message';
}

class UserAccountService {
  Future<UserAccountResetContext> loadResetContext() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = _readJsonMap(prefs.getString('user_data'));
    final selectedChild = _readJsonMap(prefs.getString('selected_child'));
    final source = userData ?? selectedChild;

    return UserAccountResetContext(
      email: _extractString(source?['email']) ?? '',
      userType:
          _extractString(userData?['usertype']) ??
          _extractString(userData?['user_type']) ??
          prefs.getString('user_type')?.trim() ??
          '',
      hasAuthToken: (prefs.getString('auth_token') ?? '').trim().isNotEmpty,
    );
  }

  Future<String> sendTemporaryPassword({required String email}) async {
    final normalizedEmail = email.trim();
    if (!_looksLikeEmail(normalizedEmail)) {
      throw const UserAccountException(
        title: 'Invalid email',
        message: 'Enter a valid registered email address.',
        fieldErrors: {'email': 'Enter a valid email address.'},
      );
    }

    final response = await _postJson(
      AppConfig.apiUri('/auth/forgot-password'),
      headers: const {
        'accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: {'email': normalizedEmail},
    );

    if (response.statusCode == 200) {
      return _extractSuccessMessage(
        response.body,
        fallbackMessage: 'Temporary password sent to the registered email.',
      );
    }

    switch (response.statusCode) {
      case 400:
        throw UserAccountException(
          title: 'Invalid email',
          message: _extractHttpError(
            response,
            'Valid email is required.',
          ),
          fieldErrors: const {'email': 'Enter a valid email address.'},
        );
      case 404:
        throw UserAccountException(
          title: 'Email not found',
          message: _extractHttpError(
            response,
            'No user found with this email.',
          ),
          fieldErrors: const {'email': 'No user found with this email.'},
        );
      default:
        throw UserAccountException(
          title: 'Temporary password failed',
          message: _extractHttpError(
            response,
            'Failed to send the temporary password.',
          ),
        );
    }
  }

  Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final normalizedCurrentPassword = currentPassword.trim();
    final normalizedNewPassword = newPassword.trim();

    if (normalizedCurrentPassword.isEmpty) {
      throw const UserAccountException(
        title: 'Invalid password input',
        message: 'Enter your current password or temporary password.',
        fieldErrors: {
          'currentPassword': 'Current or temporary password is required.',
        },
      );
    }

    if (normalizedNewPassword.isEmpty) {
      throw const UserAccountException(
        title: 'Invalid password input',
        message: 'Enter a new password.',
        fieldErrors: {'newPassword': 'New password is required.'},
      );
    }

    if (normalizedNewPassword.length < 6) {
      throw const UserAccountException(
        title: 'Invalid password input',
        message: 'New password must be at least 6 characters long.',
        fieldErrors: {'newPassword': 'Password must be at least 6 characters.'},
      );
    }

    if (normalizedCurrentPassword == normalizedNewPassword) {
      throw const UserAccountException(
        title: 'Invalid password input',
        message: 'New password must be different from the current password.',
        fieldErrors: {
          'newPassword': 'New password must be different from current password.',
        },
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token')?.trim() ?? '';

    if (token.isEmpty) {
      throw const UserAccountException(
        title: 'Session expired',
        message: 'Please login again to change your password.',
      );
    }

    final response = await _postJson(
      AppConfig.apiUri('/auth/change-password'),
      headers: {
        'accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: {
        'currentPassword': normalizedCurrentPassword,
        'newPassword': normalizedNewPassword,
      },
    );

    if (response.statusCode == 200) {
      return _extractSuccessMessage(
        response.body,
        fallbackMessage: 'Password updated successfully.',
      );
    }

    switch (response.statusCode) {
      case 400:
        throw UserAccountException(
          title: 'Invalid password input',
          message: _extractHttpError(
            response,
            'Invalid password input.',
          ),
        );
      case 401:
        throw UserAccountException(
          title: 'Unauthorized',
          message: _extractHttpError(
            response,
            'Please login again to change your password.',
          ),
        );
      case 404:
        throw UserAccountException(
          title: 'User not found',
          message: _extractHttpError(
            response,
            'User not found.',
          ),
        );
      default:
        throw UserAccountException(
          title: 'Change password failed',
          message: _extractHttpError(
            response,
            'Failed to update the password.',
          ),
        );
    }
  }

  Future<http.Response> _postJson(
    Uri endpoint, {
    required Map<String, String> headers,
    required Map<String, dynamic> body,
  }) async {
    try {
      return await http
          .post(endpoint, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const UserAccountException(
        title: 'Connection error',
        message: 'The server took too long to respond. Please try again.',
      );
    } on SocketException catch (error) {
      throw _buildNetworkException(error, endpoint);
    } on http.ClientException catch (error) {
      throw _buildNetworkException(error, endpoint);
    } catch (error) {
      throw UserAccountException(
        title: 'Connection error',
        message: AppConfig.networkErrorMessage(error),
      );
    }
  }

  UserAccountException _buildNetworkException(Object error, Uri endpoint) {
    final host = endpoint.host.toLowerCase();
    final isLocalhost = host == 'localhost' || host == '127.0.0.1';
    final rawMessage = error.toString().toLowerCase();

    if (isLocalhost &&
        (rawMessage.contains('connection refused') ||
            rawMessage.contains('failed host lookup') ||
            rawMessage.contains('socketexception') ||
            rawMessage.contains('clientexception'))) {
      return UserAccountException(
        title: 'Connection error',
        message:
            'Could not reach the local backend at ${endpoint.host}:${endpoint.port}. Check whether the backend or proxy is running.',
      );
    }

    return UserAccountException(
      title: 'Connection error',
      message: AppConfig.networkErrorMessage(error),
    );
  }

  String _extractSuccessMessage(
    String responseBody, {
    required String fallbackMessage,
  }) {
    final decoded = _decodeJsonMap(responseBody);
    final message = _extractErrorText(decoded);
    if (message != null && message.isNotEmpty) {
      return message;
    }

    return fallbackMessage;
  }

  String _extractHttpError(http.Response response, String fallbackMessage) {
    final responseBody = utf8
        .decode(response.bodyBytes, allowMalformed: true)
        .trim();
    final responseDetail = _extractErrorDetail(responseBody);
    if (responseDetail != null && responseDetail.isNotEmpty) {
      return responseDetail;
    }

    final reasonPhrase = response.reasonPhrase?.trim();
    if (reasonPhrase != null && reasonPhrase.isNotEmpty) {
      return reasonPhrase;
    }

    return fallbackMessage;
  }

  String? _extractErrorDetail(String responseBody) {
    if (responseBody.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(responseBody);
      final message = _extractErrorText(decoded);
      if (message != null && message.isNotEmpty) {
        return message;
      }
    } catch (_) {
      return responseBody;
    }

    return null;
  }

  String? _extractErrorText(dynamic value) {
    if (value is String) {
      final message = value.trim();
      return message.isEmpty ? null : message;
    }

    if (value is List) {
      for (final item in value) {
        final message = _extractErrorText(item);
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
      return null;
    }

    if (value is Map) {
      for (final key in const ['message', 'error', 'detail', 'title', 'msg']) {
        final message = _extractErrorText(value[key]);
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }

      for (final item in value.values) {
        final message = _extractErrorText(item);
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
    }

    return null;
  }

  Map<String, dynamic>? _readJsonMap(String? rawValue) {
    if (rawValue == null || rawValue.isEmpty) {
      return null;
    }

    try {
      return jsonDecode(rawValue) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _decodeJsonMap(String rawBody) {
    if (rawBody.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawBody);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  String? _extractString(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    if (value is List && value.isNotEmpty) {
      return _extractString(value.first);
    }
    return null;
  }

  bool _looksLikeEmail(String value) {
    final trimmed = value.trim();
    return trimmed.contains('@') && trimmed.contains('.');
  }
}
