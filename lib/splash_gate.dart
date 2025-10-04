// lib/splash_gate.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:intl/intl.dart';

import 'l10n/app_localizations.dart';
import 'models/user_profile.dart';
import 'services/profile_store.dart';
import 'services/purchase_service.dart';
import 'services/ads_service.dart';
import 'services/api_client.dart';
import 'screens/pro_screen.dart';
import 'main.dart' show ForecastScreen, HouseSystem; // אם ForecastScreen ו-HouseSystem מוגדרים ב-main.dart

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

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
       defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _boot() async {
    try {
      await PurchaseService.instance.init();

      final profile = await ProfileStore.load();
      if (!mounted) return;

      if (profile == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const RegistrationScreen()),
        );
        return;
      }

      final isPro = await PurchaseService.instance.isProUser();
      final lang = WidgetsBinding.instance.platformDispatcher.locale.languageCode;

      if (isPro) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ProForecastScreen(
              birthDate: profile.birthDate,
              birthTime: profile.birthTime,
              tz: profile.tz,
              lat: profile.lat.toString(),
              lon: profile.lon.toString(),
              lang: lang,
            ),
          ),
        );
      } else {
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final payload = {
          'date': today,
          'time': profile.birthTime,
          'city': profile.cityName,
          'lat': profile.lat.toString(),
          'lon': profile.lon.toString(),
          'lang': lang,
          'tz': profile.tz,
          'house_system': profile.houseSystem, // 'placidus' / 'equal' / 'whole_sign'
        };

        final resp = await Api.postForecast(payload).timeout(const Duration(seconds: 60));
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;

          if (_isMobile) {
            await AdsService.showInterstitialIfNeeded(isPro: false);
          }

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ForecastScreen(
                forecastData: data,
                birthDate: profile.birthDate,
                birthTime: profile.birthTime,
                tz: profile.tz,
                lat: profile.lat.toString(),
                lon: profile.lon.toString(),
                houseSystem: _houseFromString(profile.houseSystem),
              ),
            ),
          );
        } else {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const RegistrationScreen()),
          );
        }
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RegistrationScreen()),
      );
    }
  }

  HouseSystem _houseFromString(String s) {
    switch (s) {
      case 'equal':
        return HouseSystem.equal;
      case 'whole_sign':
        return HouseSystem.wholeSign;
      default:
        return HouseSystem.placidus;
    }
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
