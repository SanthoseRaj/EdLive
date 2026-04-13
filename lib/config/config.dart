import 'package:flutter/foundation.dart';

class AppConfig {
  // ✅ Production backend
  // static const String defaultServerOrigin =
  //     'https://schoolmanagement.canadacentral.cloudapp.azure.com';

  static const String defaultServerOrigin =
      'https://edlive-web-backend-1.onrender.com';

  // ✅ Local backend
  static const String localServerOrigin = 'http://localhost:5000';
  static const String androidEmulatorServerOrigin = 'http://10.0.2.2:5000';

  // ✅ Optional local web proxy (only if you really use one)
  static const String localProxyOrigin = 'http://127.0.0.1:8081';

  // ✅ Compile-time overrides
  static const String _serverOriginOverride = String.fromEnvironment(
    'SERVER_ORIGIN',
    defaultValue: '',
  );

  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static const String _academicYearOverride = String.fromEnvironment(
    'ACADEMIC_YEAR',
    defaultValue: '',
  );

  // ✅ Storage keys
  static const String tokenKey = 'authu_token';
  static const String userTypeKey = 'usertype';
  static const String userIdKey = 'userId';
  static const String academicYearKey = 'academicYear';

  // ✅ Global academic year cache
  static String _academicYear = '';

  /// ✅ Resolved server origin
  static String get serverOrigin {
    // 1. Highest priority → manual override from command
    if (_serverOriginOverride.isNotEmpty) {
      return _normalizeOrigin(_serverOriginOverride);
    }

    // 2. If running Flutter Web in localhost, use local backend
    if (_shouldUseLocalBackend) {
      return _resolvedLocalServerOrigin;
    }

    // 3. All deployed environments use production backend
    return defaultServerOrigin;
  }

  /// ✅ Resolved API base URL
  static String get baseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) {
      return _removeTrailingSlash(_apiBaseUrlOverride);
    }

    return '${_removeTrailingSlash(serverOrigin)}/api';
  }

  /// ✅ Academic year getter
  static String get academicYear {
    if (_academicYearOverride.isNotEmpty) {
      return _academicYearOverride;
    }

    if (_academicYear.isEmpty) {
      _academicYear = _calculateAcademicYear(DateTime.now());
    }

    return _academicYear;
  }

  /// ✅ Academic year setter
  static set academicYear(String value) {
    _academicYear = value.trim();
  }

  /// ✅ Set academic year manually or auto-calculate
  static void setAcademicYear([String? value]) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      academicYear = trimmed;
      return;
    }

    academicYear = _calculateAcademicYear(DateTime.now());
  }

  /// ✅ Academic year calculation
  static String _calculateAcademicYear(DateTime now) {
    if (now.month >= 6) {
      return '${now.year}-${now.year + 1}';
    }
    return '${now.year - 1}-${now.year}';
  }

  /// ✅ Build API Uri safely
  static Uri apiUri(String path, {Map<String, dynamic>? queryParameters}) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';

    return Uri.parse('$baseUrl$normalizedPath').replace(
      queryParameters: queryParameters?.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
  }

  /// ✅ Convert relative path to full absolute URL
  static String absoluteUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    final normalizedOrigin = _removeTrailingSlash(serverOrigin);

    if (path.startsWith('/')) {
      return '$normalizedOrigin$path';
    }

    return '$normalizedOrigin/$path';
  }

  /// ✅ Friendly network error for UI
  static String networkErrorMessage(Object error) {
    final message = error.toString().toLowerCase();

    if (message.contains('xmlhttprequest') ||
        message.contains('failed host lookup') ||
        message.contains('socketexception') ||
        message.contains('clientexception') ||
        message.contains('timed out') ||
        message.contains('connection closed')) {
      return 'Server could not be reached. If you are using Flutter Web, check whether CORS is enabled in the backend and confirm the backend URL is correct.';
    }

    return 'An unexpected network error occurred. Please try again.';
  }

  /// ✅ Local detection
  static bool get _shouldUseLocalBackend {
    // Mobile/desktop local run
    if (!kIsWeb) {
      return true;
    }

    // Web local run
    final host = Uri.base.host.toLowerCase();
    return host == 'localhost' || host == '127.0.0.1';
  }

  static String get _resolvedLocalServerOrigin {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return androidEmulatorServerOrigin;
    }

    return localServerOrigin;
  }

  /// ✅ Remove trailing slash
  static String _removeTrailingSlash(String value) {
    if (value.endsWith('/')) {
      return value.substring(0, value.length - 1);
    }
    return value;
  }

  /// ✅ Normalize origin
  static String _normalizeOrigin(String value) {
    return _removeTrailingSlash(value.trim());
  }
}
