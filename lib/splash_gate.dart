// lib/splash_gate.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'models/user_profile.dart';
import 'services/profile_store.dart';
import 'services/purchase_service.dart';
import 'screens/pro_screen.dart';

class SplashGate extends StatefulWidget {
  const SplashGate({super.key});
  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    // חימום API (לא חובה)
    try {
      final resp = await http
          .get(Uri.parse('https://lottoluck-api.onrender.com/health'))
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode >= 200 && resp.statusCode < 400) {
        // no-op
      }
    } catch (_) {/* מתעלמים משגיאות חימום */}

    // טעינת פרופיל ושאילת זכאות PRO
    final UserProfile? prof = await ProfileStore.loadUserProfile();
    final bool isPro = PurchaseService.instance.isPro;

    if (!mounted) return;

    if (prof == null) {
      // אין פרופיל → מסך הרשמה (לפי ראוט בשם, כדי לא לייבא את main.dart)
      Navigator.of(context).pushReplacementNamed('/register');
      return;
    }

    if (isPro) {
      // משתמש PRO → פותחים ישר את PRO
      final lang = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ProForecastScreen(
            birthDate: prof.birthDate,
            birthTime: prof.birthTime,
            tz: prof.tz,
            lat: prof.lat.toString(),
            lon: prof.lon.toString(),
            lang: lang,
          ),
        ),
      );
    } else {
      // חינמי: ניגש למסך הרשמה (שבדקת בו כבר את נעילת השדות/טעינה מה-ProfileStore)
      Navigator.of(context).pushReplacementNamed('/register');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
