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
  bool get isStoreAvailable => _available;

  bool _isPro = false;
  bool get isPro => _isPro;

  /// API נוח לשימוש בספלש/מקומות אחרים
  Future<bool> isProActive() async => _isPro;

  ProductDetails? _proDetails;
  ProductDetails? get proDetails => _proDetails;

  /// מפתח לשמירת זכאות באופן מקומי
  static const _kIsProKey = 'is_pro_entitlement';

  /// קריאה ראשונית: טוען סטטוס, בודק חנות, מאזין לעדכוני רכישה ומושך מוצר
  Future<void> init() async {
    // 1) קרא זכאות שמורה (אם הייתה רכישה בעבר)
    final prefs = await SharedPreferences.getInstance();
    _isPro = prefs.getBool(_kIsProKey) ?? false;

    // 2) בדיקת זמינות החנות
    _available = await _iap.isAvailable();

    // 3) האזן לזרם רכישות
    await _sub?.cancel();
    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _sub?.cancel(),
      onError: (Object e, StackTrace s) {
        // אפשר להוסיף לוג/דיווח
      },
    );

    // 4) משוך פרטי מוצר
    if (_available) {
      await refreshProducts();
      // 5) שחזור רכישות (כדי להעניק זכאות במכשיר חדש/התקנה מחדש)
      await restorePurchases();
    }

    notifyListeners();
  }

  Future<void> disposeService() async {
    await _sub?.cancel();
  }

  /// מושך פרטי מוצר מהחנות (מחיר, מטבע וכו')
  Future<void> refreshProducts() async {
    final resp = await _iap.queryProductDetails({kProProductId});
    if (resp.error == null && resp.productDetails.isNotEmpty) {
      _proDetails = resp.productDetails.first;
      notifyListeners();
    }
  }

  /// פתיחת חלון רכישה של המוצר
  Future<void> buyPro() async {
    if (!_available) {
      throw Exception('החנות אינה זמינה במכשיר זה כרגע.');
    }
    if (_proDetails == null) {
      await refreshProducts();
      if (_proDetails == null) {
        throw Exception('פרטי המוצר לא נטענו מהחנות.');
      }
    }
    final purchaseParam = PurchaseParam(productDetails: _proDetails!);
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  /// שחזור רכישות (למשתמש שהחליף מכשיר/התקין מחדש)
  Future<void> restorePurchases() async {
    if (!_available) return;
    await _iap.restorePurchases();
  }

  /// מאזין לעדכוני הרכישות מהחנות
  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // ⚠️ לפרודקשן מומלץ אימות שרת–ל–שרת כאן.
          await _entitlePro();
          if (p.pendingCompletePurchase) {
            await _iap.completePurchase(p);
          }
          break;

        case PurchaseStatus.pending:
          // אפשר להציג ספינר/מצב ממתין ב-UI
          break;

        case PurchaseStatus.error:
          // אפשר להראות שגיאה למשתמש (SnackBar/דיאלוג) ולרשום לוג
          if (p.pendingCompletePurchase) {
            // לרוב אין צורך להשלים, אבל אם התקבל דגל – נסגור את הטרנזאקציה
            await _iap.completePurchase(p);
          }
          break;

        case PurchaseStatus.canceled:
          // המשתמש ביטל – אין פעולה נוספת
          if (p.pendingCompletePurchase) {
            await _iap.completePurchase(p);
          }
          break;
      }
    }
  }

  /// הענקת זכאות PRO ושמירה מקומית
  Future<void> _entitlePro() async {
    if (_isPro) return;
    _isPro = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsProKey, true);
    notifyListeners();
  }

  /// אופציונלי לדיבוג: מחיקת הזכאות המקומית
  Future<void> debugRevoke() async {
    _isPro = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsProKey, false);
    notifyListeners();
  }
}
