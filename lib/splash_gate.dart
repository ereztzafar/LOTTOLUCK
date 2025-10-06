// lib/splash_gate.dart
import 'dart:async';
import 'package:flutter/material.dart';
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
  final _splashImage = const AssetImage('assets/images/lucky_balls.png');

  @override
  void initState() {
    super.initState();
    _startApp();
  }

  Future<void> _startApp() async {
    // טוען את התמונה מראש
    await precacheImage(_splashImage, context);

    // השהייה של 2 שניות בלבד
    await Future.delayed(const Duration(seconds: 2));

    // טוען פרופיל ומשתמש
    final UserProfile? prof = await ProfileStore.loadUserProfile();
    final bool isPro = PurchaseService.instance.isPro;

    if (!mounted) return;

    // מעבר למסך המתאים
    if (prof == null) {
      Navigator.of(context).pushReplacementNamed('/register');
    } else if (isPro) {
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
      Navigator.of(context).pushReplacementNamed('/register');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // תמונה על כל המסך
          Image(
            image: _splashImage,
            fit: BoxFit.cover,
          ),

          // אופציונלי: שכבה שקופה עדינה
          Container(color: Colors.black.withOpacity(0.05)),
        ],
      ),
    );
  }
}
