// lib/services/api_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

/// כתובת הבסיס ניתנת להחלפה בזמן build:
/// flutter build apk --release --dart-define=BASE_URL=https://lottoluck-api.onrender.com
const String kBaseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'https://lottoluck-api.onrender.com',
);

Uri _u(String path) => Uri.parse('$kBaseUrl$path');

const Map<String, String> _jsonHeaders = {
  'Content-Type': 'application/json; charset=utf-8',
  'Accept': 'application/json',
};

Map<String, dynamic> _decodeJsonBody(http.Response r) {
  final text = utf8.decode(r.bodyBytes);
  final obj = jsonDecode(text);
  if (obj is Map<String, dynamic>) return obj;
  throw Exception('Unexpected JSON shape: $text');
}

class Api {
  // נקודות קצה
  static Uri health()   => _u('/health');
  static Uri forecast() => _u('/forecast');
  static Uri pro()      => _u('/pro_forecast');

  // קריאות נוחות שמחזירות Map<String, dynamic>
  static Future<Map<String, dynamic>> getHealth() async {
    final resp = await http.get(health()).timeout(const Duration(seconds: 30));
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return _decodeJsonBody(resp);
    }
    throw Exception('HTTP ${resp.statusCode} ${health()} ${utf8.decode(resp.bodyBytes)}');
  }

  static Future<Map<String, dynamic>> postForecast(Map<String, dynamic> body) async {
    final resp = await http
        .post(forecast(), headers: _jsonHeaders, body: jsonEncode(body))
        .timeout(const Duration(seconds: 60));

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return _decodeJsonBody(resp);
    }
    throw Exception('HTTP ${resp.statusCode} ${forecast()} ${utf8.decode(resp.bodyBytes)}');
  }

  static Future<Map<String, dynamic>> postPro(Map<String, dynamic> body) async {
    final resp = await http
        .post(pro(), headers: _jsonHeaders, body: jsonEncode(body))
        .timeout(const Duration(seconds: 90));

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return _decodeJsonBody(resp);
    }
    throw Exception('HTTP ${resp.statusCode} ${pro()} ${utf8.decode(resp.bodyBytes)}');
  }
}
