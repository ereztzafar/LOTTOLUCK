// lib/splash_gate.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'l10n/app_localizations.dart';
import 'services/purchase_service.dart';
import 'services/profile_store.dart';
import 'models/user_profile.dart';
import 'screens/pro_screen.dart';

// צריך את האנום HouseSystem ואת ForecastScreen/RegistrationScreen שמוגדרים ב-main.dart
import 'widgets/astro_wheel.dart' show HouseSystem;
import 'main.dart' show ForecastScreen, RegistrationScreen;

class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  @override
  void initState() {
    super.initState();
    // מתחילים את הניווט מיד לאחר הציור הראשון של המסך
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  HouseSystem _houseSystemFromString(String s) {
    switch ((s).toLowerCase()) {
      case 'whole_sign':
      case 'whole-sign':
      case 'wholesign':
        return HouseSystem.wholeSign;
      case 'equal':
        return HouseSystem.equal;
      case 'placidus':
      default:
        return HouseSystem.placidus;
    }
  }

  Future<void> _bootstrap() async {
    final l = AppLocalizations.of(context);

    // 1) טען פרופיל אם קיים
    final UserProfile? prof = await ProfileStore.loadUserProfile();

    // אין פרופיל? → לרישום
    if (prof == null) {
      _go(const RegistrationScreen());
      return;
    }

    // יש פרופיל; בדוק אם המשתמש PRO
    final bool isPro = PurchaseService.instance.isPro;

    if (isPro) {
      // 2א) משתמש פרו → פותח ישר את מסך ה-Pro (הוא יבצע את הקריאה בעצמו)
      final lang = Localizations.localeOf(context).languageCode;
      _go(ProForecastScreen(
        birthDate: prof.birthDate,
        birthTime: prof.birthTime,
        tz: prof.tz,
        lat: prof.lat.toString(),
        lon: prof.lon.toString(),
        lang: lang,
      ));
      return;
    }

    // 2ב) משתמש חינמי → מביא תחזית ואז פותח את ForecastScreen
    try {
      final lang = Localizations.localeOf(context).languageCode;
      final uri = Uri.parse('https://lottoluck-api.onrender.com/forecast');

      final payload = <String, dynamic>{
        'date': prof.birthDate,                 // yyyy-MM-dd
        'time': prof.birthTime,                 // HH:mm
        'city': prof.cityName,
        'lat': prof.lat.toString(),
        'lon': prof.lon.toString(),
        'lang': lang,
        'tz': prof.tz,                          // IANA tz
        'house_system': prof.houseSystem,       // 'placidus' | 'whole_sign' | 'equal'
      };

      final http.Response resp = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 60));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final Map<String, dynamic> data =
            jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;

        _go(ForecastScreen(
          forecastData: data,
          birthDate: prof.birthDate,
          birthTime: prof.birthTime,
          tz: prof.tz,
          lat: prof.lat.toString(),
          lon: prof.lon.toString(),
          houseSystem: _houseSystemFromString(prof.houseSystem),
        ));
      } else {
        // שגיאה בשרת – נשלח את המשתמש למסך רישום כ־fallback
        _go(const RegistrationScreen());
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l?.error_running_forecast('HTTP ${resp.statusCode}') ??
                'Server error: ${resp.statusCode}'),
          ),
        );
      }
    } catch (e) {
      // תקלת רשת/זמן קצוב – לרישום
      _go(const RegistrationScreen());
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l?.error_running_forecast(e.toString()) ?? '$e')),
      );
    }
  }

  void _go(Widget page) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    // מסך התזמון (ספלש) – שמרתי על עיצוב וצבעים
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.amber),
              SizedBox(height: 16),
              Text(
                'LOTTOLUCK',
                style: TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
