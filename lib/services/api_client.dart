// lib/services/api_client.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiClient {
  ApiClient._();
  static final ApiClient I = ApiClient._();

  /// קבע בסיס URL לפי פלטפורמה/סביבת ריצה
  String get baseUrl {
    // PROD - כתובת ה-Render שלך:
    const renderBase = 'https://lottoluck.onrender.com';

    // Web תמיד ידבר מול השרת בענן (אין 10.0.2.2 בדפדפן)
    if (kIsWeb) return renderBase;

    // Debug במכשיר/אמולטור:
    if (!kReleaseMode) {
      if (Platform.isAndroid) return 'http://10.0.2.2:8000';
      return 'http://127.0.0.1:8000'; // iOS simulator / desktop
    }

    // Release על מכשיר אמיתי – גם כן לשרת בענן
    return renderBase;
  }

  Future<Map<String, dynamic>> forecast({
    required String date,      // YYYY-MM-DD
    required String time,      // HH:mm
    required String city,
    required double lat,
    required double lon,
    String lang = 'he',
    String tz = 'Asia/Jerusalem',
    String houseSystem = 'placidus',
  }) async {
    final uri = Uri.parse('$baseUrl/forecast');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({
        'date': date,
        'time': time,
        'city': city,
        'lat': lat,
        'lon': lon,
        'lang': lang,
        'tz': tz,
        'house_system': houseSystem,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    }
    throw Exception('forecast ${res.statusCode}: ${res.body}');
  }

  Future<Map<String, dynamic>> proForecast({
    required String transitDate,
    required String birthDate,
    required String birthTime,
    required String tz,
    required double lat,
    required double lon,
    String lang = 'he',
  }) async {
    final uri = Uri.parse('$baseUrl/pro_forecast');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({
        'transit_date': transitDate,
        'birth_date': birthDate,
        'birth_time': birthTime,
        'tz': tz,
        'lat': lat,
        'lon': lon,
        'lang': lang,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    }
    throw Exception('pro_forecast ${res.statusCode}: ${res.body}');
  }
}
