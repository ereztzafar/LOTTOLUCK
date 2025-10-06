// lib/services/forecast_cache.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ForecastCache {
  static const _k = 'last_forecast_json';

  static Future<Map<String, dynamic>?> load() async {
    final sp = await SharedPreferences.getInstance();
    final s = sp.getString(_k);
    if (s == null) return null;
    try {
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(Map<String, dynamic> data) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_k, jsonEncode(data));
  }
}
