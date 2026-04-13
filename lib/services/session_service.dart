import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  const SessionService._();

  static Future<void> clearStoredSession() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().toList(growable: false);

    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}