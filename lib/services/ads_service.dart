import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdsService {
  static bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static String get _bannerId => Platform.isAndroid
    ? 'ca-app-pub-6988579003966858/6151952401' // Android REAL banner
    : 'ca-app-pub-6988579003966858/6151952401'; // iOS placeholder if you add later

static String get _interstitialId => Platform.isAndroid
    ? 'ca-app-pub-6988579003966858/6151952401' // אם תיצור Interstitial נפרד תעדכן כאן
    : 'ca-app-pub-6988579003966858/6151952401';

  static Future<void> init() async {
    if (!_isMobile) return;
    await MobileAds.instance.initialize();
  }

  static Widget banner({EdgeInsets padding = EdgeInsets.zero}) {
    if (!_isMobile) return const SizedBox.shrink();
    return FutureBuilder<BannerAd>(
      future: _loadBanner(),
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done || !snap.hasData) {
          return const SizedBox.shrink();
        }
        final ad = snap.data!;
        return Padding(
          padding: padding,
          child: SizedBox(
            width: ad.size.width.toDouble(),
            height: ad.size.height.toDouble(),
            child: AdWidget(ad: ad),
          ),
        );
      },
    );
  }

  static Future<BannerAd> _loadBanner() async {
    final ad = BannerAd(
      size: AdSize.banner,
      request: const AdRequest(),
      adUnitId: _bannerId,
      listener: const BannerAdListener(),
    );
    await ad.load();
    return ad;
  }

  static Future<void> showInterstitialIfNeeded({required bool isPro}) async {
    if (!_isMobile || isPro) return;
    final completer = Completer<void>();
    InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) { ad.dispose(); completer.complete(); },
            onAdFailedToShowFullScreenContent: (ad, err) { ad.dispose(); completer.complete(); },
          );
          ad.show();
        },
        onAdFailedToLoad: (err) { completer.complete(); },
      ),
    );
    return completer.future;
  }
}
