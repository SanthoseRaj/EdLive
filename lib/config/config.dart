import 'package:flutter/foundation.dart';

class AppConfig {
  static const String defaultServerOrigin =
      'https://schoolmanagement.canadacentral.cloudapp.azure.com:443';
  static const String defaultApiBaseUrl = '$defaultServerOrigin/api';
  static const String localProxyOrigin = 'http://127.0.0.1:8081';

  static const String _serverOriginOverride = String.fromEnvironment(
    'SERVER_ORIGIN',
    defaultValue: '',
  );
  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get serverOrigin {
    if (_serverOriginOverride.isNotEmpty) {
      return _serverOriginOverride;
    }

    if (_shouldUseLocalProxy) {
      return localProxyOrigin;
    }

    return defaultServerOrigin;
  }

  static String get baseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) {
      return _apiBaseUrlOverride;
    }

    return '$serverOrigin/api';
  }

  static const String tokenKey = 'authu_token';
  static const String userTypeKey = 'usertype';
  static const String userIdKey = 'userId';
  static const String academicYearKey = 'academicYear';
  static const String _academicYearOverride = String.fromEnvironment(
    'ACADEMIC_YEAR',
    defaultValue: '',
  );

  // ✅ GLOBAL ACADEMIC YEAR
  static String _academicYear = '';

  static String get academicYear {
    if (_academicYearOverride.isNotEmpty) {
      return _academicYearOverride;
    }

    if (_academicYear.isEmpty) {
      _academicYear = _calculateAcademicYear(DateTime.now());
    }

    return _academicYear;
  }

  static set academicYear(String value) {
    _academicYear = value.trim();
  }

  static void setAcademicYear([String? value]) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      academicYear = trimmed;
      return;
    }

    academicYear = _calculateAcademicYear(DateTime.now());
  }

  static String _calculateAcademicYear(DateTime now) {
    if (now.month >= 6) {
      return '${now.year}-${now.year + 1}';
    }

    return '${now.year - 1}-${now.year}';
  }

  // ✅ API URI BUILDER
  static Uri apiUri(String path, {Map<String, dynamic>? queryParameters}) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalizedPath').replace(
      queryParameters: queryParameters?.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
  }

  static String absoluteUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    if (path.startsWith('/')) {
      return '$serverOrigin$path';
    }

    return '$serverOrigin/$path';
  }

  static String networkErrorMessage(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('xmlhttprequest') ||
        message.contains('failed host lookup') ||
        message.contains('socketexception') ||
        message.contains('clientexception') ||
        message.contains('timed out') ||
        message.contains('connection closed')) {
      return 'Server could not be reached from this browser. On Flutter web, this usually means the backend is blocking CORS or you need to route requests through a local proxy.';
    }

    return 'An unexpected network error occurred. Please try again.';
  }

  static bool get _shouldUseLocalProxy {
    if (!kIsWeb) {
      return false;
    }

    final host = Uri.base.host.toLowerCase();
    return host == 'localhost' || host == '127.0.0.1';
  }
}
