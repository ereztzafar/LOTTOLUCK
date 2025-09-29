// lib/services/purchase_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// מזהה המוצר ב-Google Play Console (Managed Product / Non-consumable)
const String kProProductId = 'pro_unlock';

class PurchaseService with ChangeNotifier {
  PurchaseService._internal();
  static final PurchaseService instance = PurchaseService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  bool _available = false;
  bool _isPro = false;
  bool get isPro => _isPro;

  ProductDetails? _proDetails;
  ProductDetails? get proDetails => _proDetails;

  /// שמות מפתחות בלוקאל סטורג'
  static const _kIsProKey = 'is_pro_entitlement';

  Future<void> init() async {
    // קרא סטטוס שמור
    final prefs = await SharedPreferences.getInstance();
    _isPro = prefs.getBool(_kIsProKey) ?? false;

    // בדיקת זמינות החנות (Play)
    _available = await _iap.isAvailable();

    // מאזין לעדכוני רכישה
    _sub?.cancel();
    _sub = _iap.purchaseStream.listen(_onPurchaseUpdate, onDone: () {
      _sub?.cancel();
    }, onError: (Object e, StackTrace s) {
      // אפשר להוסיף לוג
    });

    // משוך פרטי מוצר
    if (_available) {
      final resp = await _iap.queryProductDetails({kProProductId});
      if (resp.error == null && resp.productDetails.isNotEmpty) {
        _proDetails = resp.productDetails.first;
      }
    }

    // אם כבר מסומן PRO לוקאלי, נוודא/נשחזר ברקע (לא חובה לגרסה ראשונית)
    // restore() יגרום ל-emission מחדש ב-purchaseStream אם יש רכישה קיימת
    if (_available) {
      // אפשר להריץ ברקע; כאן מריצים סינכרונית כדי לשמור על פשטות
      await restorePurchases();
    }

    notifyListeners();
  }

  Future<void> disposeService() async {
    await _sub?.cancel();
  }

  Future<void> buyPro() async {
    if (!_available || _proDetails == null) {
      throw Exception('Store not available or product not loaded');
    }
    final purchaseParam = PurchaseParam(productDetails: _proDetails!);
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> restorePurchases() async {
    if (!_available) return;
    // החל מ-billing v5, אין queryPastPurchases יש restorePurchases()
    await _iap.restorePurchases();
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // נקודת אימות (ב-MVP מאשרים מקומית; לפרודקשן מומלץ אימות שרת)
          await _entitlePro();
          // יש להשלים את הרכישה כדי לסגור את ה-transaction
          if (p.pendingCompletePurchase) {
            await _iap.completePurchase(p);
          }
          break;

        case PurchaseStatus.pending:
          // אפשר להציג ספינר אם רוצים
          break;

        case PurchaseStatus.error:
          // לוג/טוסט למשתמש
          break;

        case PurchaseStatus.canceled:
          // לא לעשות כלום
          break;
      }
    }
  }

  Future<void> _entitlePro() async {
    if (_isPro) return;
    _isPro = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsProKey, true);
    notifyListeners();
  }

  /// אופציונלי: ניקוי זכאות (לדיבוג בלבד)
  Future<void> debugRevoke() async {
    _isPro = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsProKey, false);
    notifyListeners();
  }
}
