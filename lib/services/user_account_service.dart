import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:school_app/config/config.dart';

class UserAccountDraft {
  final int userId;
  final String fullname;
  final String username;
  final String email;
  final String phoneNumber;
  final String usertype;

  const UserAccountDraft({
    required this.userId,
    required this.fullname,
    required this.username,
    required this.email,
    required this.phoneNumber,
    required this.usertype,
  });

  UserAccountDraft copyWith({
    int? userId,
    String? fullname,
    String? username,
    String? email,
    String? phoneNumber,
    String? usertype,
  }) {
    return UserAccountDraft(
      userId: userId ?? this.userId,
      fullname: fullname ?? this.fullname,
      username: username ?? this.username,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      usertype: usertype ?? this.usertype,
    );
  }

  Map<String, dynamic> toUpdatePayload({required String password}) {
    return {
      'fullname': fullname,
      'username': username,
      'email': email,
      'phone_number': phoneNumber,
      'password': password,
      'usertype': usertype,
    };
  }
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
  Future<UserAccountDraft> loadCurrentAccountDraft() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadLocalAccountDraft(prefs);
  }

  UserAccountDraft _loadLocalAccountDraft(SharedPreferences prefs) {
    final source = _resolveActiveUserData(prefs);
    final userId =
        _extractPositiveInt(source?['user_id']) ??
        _extractPositiveInt(source?['id']);

    if (source == null || userId == null) {
      throw const UserAccountException(
        title: 'Reset password section',
        message:
            'Unable to identify the current user. Please login again and try again.',
      );
    }

    return UserAccountDraft(
      userId: userId,
      fullname:
          _extractString(source['fullname']) ??
          _extractString(source['full_name']) ??
          _extractString(source['name']) ??
          '',
      username:
          _extractString(source['username']) ??
          _extractString(source['user_name']) ??
          '',
      email: _extractString(source['email']) ?? '',
      phoneNumber:
          _extractString(source['phone_number']) ??
          _extractString(source['phone']) ??
          _extractString(source['contact_number']) ??
          _extractString(source['contact']) ??
          _extractString(source['mobile']) ??
          '',
      usertype: _normalizeUserType(
        _extractString(source['usertype']) ??
            _extractString(source['user_type']) ??
            prefs.getString('user_type') ??
            '',
      ),
    );
  }

  Future<UserAccountDraft> updateCurrentUser({
    required UserAccountDraft draft,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final currentAccountDraft = _loadLocalAccountDraft(prefs);

    if (token == null || token.trim().isEmpty) {
      throw const UserAccountException(
        title: 'Reset password section',
        message: 'No authentication token found. Please login again.',
      );
    }

    final verifiedDraft = await _loadAccountProfileByUsername(
      username: draft.username,
      token: token,
      fallbackDraft: currentAccountDraft,
    );
    _throwIfDifferentAccount(
      currentAccount: currentAccountDraft,
      profileAccount: verifiedDraft,
    );
    _throwIfIdentityMismatch(expected: verifiedDraft, actual: draft);

    final endpoint = AppConfig.apiUri(
      '/users/users/${currentAccountDraft.userId}',
    );
    late final http.Response response;

    try {
      response = await http
          .put(
            endpoint,
            headers: {
              'accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(verifiedDraft.toUpdatePayload(password: password)),
          )
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw UserAccountException(
        title: 'Connection error',
        message:
            'Reset password section could not reach the server in time. Please try again.',
      );
    } on SocketException catch (error) {
      throw _buildNetworkException(error, endpoint);
    } on http.ClientException catch (error) {
      throw _buildNetworkException(error, endpoint);
    } catch (error) {
      throw _buildUnexpectedException(error);
    }

    if (response.statusCode == 200) {
      final updatedDraft = _mergeResponseIntoDraft(
        verifiedDraft,
        _decodeJsonMap(response.body),
      );
      await _persistUpdatedAccount(prefs, updatedDraft);
      return updatedDraft;
    }

    switch (response.statusCode) {
      case 400:
        throw UserAccountException(
          title: 'Validation error',
          message: _extractHttpError(
            response,
            'Reset password section contains invalid input.',
          ),
        );
      case 403:
        throw UserAccountException(
          title: 'Access denied',
          message: _extractHttpError(
            response,
            'Reset password section is not allowed for this account.',
          ),
        );
      case 404:
        throw UserAccountException(
          title: 'User not found',
          message: _extractHttpError(
            response,
            'Reset password section could not find this user.',
          ),
        );
      case 409:
        throw UserAccountException(
          title: 'Duplicate email',
          message: _extractHttpError(
            response,
            'The email address is already in use by another user.',
          ),
        );
      default:
        throw UserAccountException(
          title: 'Reset password failed',
          message: _extractHttpError(
            response,
            'Reset password section failed (${response.statusCode}).',
          ),
        );
    }
  }

  Future<UserAccountDraft> _loadAccountProfileByUsername({
    required String username,
    required String token,
    required UserAccountDraft fallbackDraft,
  }) async {
    final normalizedUsername = username.trim();
    if (normalizedUsername.isEmpty) {
      throw const UserAccountException(
        title: 'Details mismatch',
        message: 'Username is required to verify your account details.',
        fieldErrors: {'username': 'Username is required.'},
      );
    }

    final endpoint = AppConfig.apiUri(
      '/users/profile/${Uri.encodeComponent(normalizedUsername)}',
    );
    late final http.Response response;

    try {
      final headers = <String, String>{'accept': 'application/json'};
      if (token.trim().isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      response = await http
          .get(endpoint, headers: headers)
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw UserAccountException(
        title: 'Connection error',
        message:
            'Reset password section could not verify your saved account details in time. Please try again.',
      );
    } on SocketException catch (error) {
      throw _buildNetworkException(error, endpoint);
    } on http.ClientException catch (error) {
      throw _buildNetworkException(error, endpoint);
    } catch (error) {
      throw _buildUnexpectedException(error);
    }

    if (response.statusCode == 200) {
      final responseData = _decodeJsonMap(response.body);
      final source = _extractPrimaryPayload(responseData);
      if (source == null) {
        throw const UserAccountException(
          title: 'Verification failed',
          message:
              'Reset password section could not read the saved account details from the server. Please try again.',
        );
      }

      return _buildDraftFromSource(source, fallbackDraft: fallbackDraft);
    }

    switch (response.statusCode) {
      case 400:
        throw UserAccountException(
          title: 'Verification failed',
          message: _extractHttpError(
            response,
            'Unable to verify the saved account details. Please try again.',
          ),
        );
      case 403:
        throw UserAccountException(
          title: 'Access denied',
          message: _extractHttpError(
            response,
            'You are not allowed to verify this account.',
          ),
        );
      case 404:
        throw const UserAccountException(
          title: 'Details mismatch',
          message:
              'Username does not match the account details saved in the system. Please check and try again.',
          fieldErrors: {'username': 'Username does not match our records.'},
        );
      default:
        throw UserAccountException(
          title: 'Verification failed',
          message: _extractHttpError(
            response,
            'Unable to verify the saved account details right now. Please try again.',
          ),
        );
    }
  }

  void _throwIfDifferentAccount({
    required UserAccountDraft currentAccount,
    required UserAccountDraft profileAccount,
  }) {
    if (profileAccount.userId == currentAccount.userId) {
      return;
    }

    throw const UserAccountException(
      title: 'Details mismatch',
      message:
          'The entered username belongs to a different account. Please use the username saved for the current account.',
      fieldErrors: {'username': 'Username belongs to a different account.'},
    );
  }

  void _throwIfIdentityMismatch({
    required UserAccountDraft expected,
    required UserAccountDraft actual,
  }) {
    final fieldErrors = <String, String>{};
    final mismatchedLabels = <String>[];

    void addMismatch({
      required bool matches,
      required String fieldKey,
      required String label,
    }) {
      if (matches) {
        return;
      }

      fieldErrors[fieldKey] = '$label does not match our records.';
      mismatchedLabels.add(label);
    }

    addMismatch(
      matches: _matchesLooseText(expected.fullname, actual.fullname),
      fieldKey: 'fullname',
      label: 'Full name',
    );
    addMismatch(
      matches: _matchesLooseText(expected.username, actual.username),
      fieldKey: 'username',
      label: 'Username',
    );
    addMismatch(
      matches: _matchesLooseText(expected.email, actual.email),
      fieldKey: 'email',
      label: 'Email',
    );

    if (fieldErrors.isEmpty) {
      return;
    }

    final message = mismatchedLabels.length == 1
        ? '${mismatchedLabels.first} does not match the account details saved in the system. Please check and try again.'
        : 'These details do not match the account details saved in the system: ${mismatchedLabels.join(', ')}. Please check and try again.';

    throw UserAccountException(
      title: 'Details mismatch',
      message: message,
      fieldErrors: fieldErrors,
    );
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
            'Reset password section could not reach the local server at ${endpoint.host}:${endpoint.port}. If you are testing on Android emulator, use 10.0.2.2 instead of localhost.',
      );
    }

    return UserAccountException(
      title: 'Connection error',
      message:
          'Reset password section could not reach the server. Please check the backend URL and network connection.',
    );
  }

  UserAccountException _buildUnexpectedException(Object error) {
    return UserAccountException(
      title: 'Reset password failed',
      message: AppConfig.networkErrorMessage(error),
    );
  }

  Future<void> _persistUpdatedAccount(
    SharedPreferences prefs,
    UserAccountDraft draft,
  ) async {
    final userData = _readJsonMap(prefs.getString('user_data'));
    if (_matchesDraft(userData, draft.userId)) {
      _applyDraftToUserData(userData!, draft);
      await prefs.setString('user_data', jsonEncode(userData));
    }

    final selectedChild = _readJsonMap(prefs.getString('selected_child'));
    if (_matchesDraft(selectedChild, draft.userId)) {
      _applyDraftToSelectedChild(selectedChild!, draft);
      await prefs.setString('selected_child', jsonEncode(selectedChild));
    }
  }

  UserAccountDraft _mergeResponseIntoDraft(
    UserAccountDraft draft,
    Map<String, dynamic>? responseData,
  ) {
    if (responseData == null) {
      return draft;
    }

    return draft.copyWith(
      userId:
          _extractPositiveInt(responseData['id']) ??
          _extractPositiveInt(responseData['user_id']),
      fullname:
          _extractString(responseData['fullname']) ??
          _extractString(responseData['full_name']),
      username:
          _extractString(responseData['username']) ??
          _extractString(responseData['user_name']),
      email: _extractString(responseData['email']),
      phoneNumber:
          _extractString(responseData['phone_number']) ??
          _extractString(responseData['phone']),
      usertype: _normalizeUserType(
        _extractString(responseData['usertype']) ??
            _extractString(responseData['user_type']) ??
            draft.usertype,
      ),
    );
  }

  UserAccountDraft _buildDraftFromSource(
    Map<String, dynamic> source, {
    required UserAccountDraft fallbackDraft,
  }) {
    return fallbackDraft.copyWith(
      userId:
          _extractPositiveInt(source['id']) ??
          _extractPositiveInt(source['user_id']),
      fullname:
          _extractString(source['fullname']) ??
          _extractString(source['full_name']) ??
          _extractString(source['name']),
      username:
          _extractString(source['username']) ??
          _extractString(source['user_name']),
      email: _extractString(source['email']),
      phoneNumber:
          _extractString(source['phone_number']) ??
          _extractString(source['phone']) ??
          _extractString(source['contact_number']) ??
          _extractString(source['contact']) ??
          _extractString(source['mobile']),
      usertype: _normalizeUserType(
        _extractString(source['usertype']) ??
            _extractString(source['user_type']) ??
            fallbackDraft.usertype,
      ),
    );
  }

  Map<String, dynamic>? _extractPrimaryPayload(Map<String, dynamic>? source) {
    if (source == null) {
      return null;
    }

    for (final key in const ['user', 'data', 'result']) {
      final value = source[key];
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
    }

    return source;
  }

  Map<String, dynamic>? _resolveActiveUserData(SharedPreferences prefs) {
    final loggedInUserType = prefs.getString('user_type')?.toLowerCase();
    final userData = _readJsonMap(prefs.getString('user_data'));
    final selectedChild = _readJsonMap(prefs.getString('selected_child'));

    if (loggedInUserType == 'teacher') {
      return userData;
    }

    final selectedChildType =
        selectedChild?['user_type']?.toString().toLowerCase() ?? '';
    if (selectedChild != null &&
        selectedChildType != 'staff' &&
        selectedChildType != 'teacher') {
      return selectedChild;
    }

    return selectedChild ?? userData;
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

  bool _matchesDraft(Map<String, dynamic>? source, int userId) {
    if (source == null) {
      return false;
    }

    return _extractPositiveInt(source['user_id']) == userId ||
        _extractPositiveInt(source['id']) == userId;
  }

  void _applyDraftToUserData(
    Map<String, dynamic> target,
    UserAccountDraft draft,
  ) {
    target['id'] = draft.userId;
    target['user_id'] = draft.userId;
    target['fullname'] = draft.fullname;
    target['full_name'] = draft.fullname;
    target['name'] = draft.fullname;
    target['username'] = draft.username;
    target['user_name'] = draft.username;
    target['email'] = draft.email;
    target['phone_number'] = draft.phoneNumber;
    target['phone'] = draft.phoneNumber;
    target['contact_number'] = draft.phoneNumber;
    target['contact'] = draft.phoneNumber;
    target['mobile'] = draft.phoneNumber;
    target['usertype'] = draft.usertype;
    target['user_type'] = draft.usertype;
  }

  void _applyDraftToSelectedChild(
    Map<String, dynamic> target,
    UserAccountDraft draft,
  ) {
    target['user_id'] = draft.userId;
    target['fullname'] = draft.fullname;
    target['full_name'] = draft.fullname;
    target['name'] = draft.fullname;
    target['username'] = draft.username;
    target['user_name'] = draft.username;
    target['email'] = draft.email;
    target['phone_number'] = draft.phoneNumber;
    target['phone'] = draft.phoneNumber;
    target['contact_number'] = draft.phoneNumber;
    target['contact'] = draft.phoneNumber;
    target['mobile'] = draft.phoneNumber;
    target['usertype'] = draft.usertype;
    target['user_type'] = draft.usertype;
  }

  int? _extractPositiveInt(dynamic value) {
    if (value is int && value > 0) {
      return value;
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }
    if (value is List && value.isNotEmpty) {
      return _extractPositiveInt(value.first);
    }
    return null;
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

  String _normalizeUserType(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    switch (trimmed.toLowerCase()) {
      case 'staff':
      case 'teacher':
        return 'Teacher';
      case 'student':
        return 'Student';
      case 'parent':
        return 'Parent';
      case 'staff admin':
      case 'staff_admin':
        return 'Staff Admin';
      default:
        return trimmed
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .map(
              (part) =>
                  '${part.substring(0, 1).toUpperCase()}${part.substring(1).toLowerCase()}',
            )
            .join(' ');
    }
  }

  bool _matchesLooseText(String expected, String actual) {
    return _normalizeLooseText(expected) == _normalizeLooseText(actual);
  }

  String _normalizeLooseText(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
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
}
