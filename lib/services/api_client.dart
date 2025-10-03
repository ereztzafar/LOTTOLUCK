// lib/services/api_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class Api {
  // כתובת השרת בענן
  static const String baseUrl = 'https://lottoluck-api.onrender.com';

  static Uri health()   => Uri.parse('$baseUrl/health');
  static Uri forecast() => Uri.parse('$baseUrl/forecast');
  static Uri pro()      => Uri.parse('$baseUrl/pro_forecast');

  static Future<http.Response> postForecast(Map<String, dynamic> body) {
    return http.post(
      forecast(),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> postPro(Map<String, dynamic> body) {
    return http.post(
      pro(),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
  }
}
