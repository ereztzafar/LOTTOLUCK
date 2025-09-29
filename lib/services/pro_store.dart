import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ניהול סטטוס PRO (פשטני: נשמר ב-SharedPreferences)
class ProStore extends ChangeNotifier {
  static const _key = 'is_pro_v1';

  bool _isPro = false;
  bool get isPro => _isPro;

  /// טוען מהאחסון המקומי
  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    _isPro = sp.getBool(_key) ?? false;
    notifyListeners();
  }

  /// הפעלה ידנית של PRO (לצורך דמו / רכישה בהמשך)
  Future<void> upgradeToPro() async {
    _isPro = true;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_key, true);
    notifyListeners();
  }

  /// ביטול PRO (נוח לבדיקות)
  Future<void> downgradeToFree() async {
    _isPro = false;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_key, false);
    notifyListeners();
  }

  /// טוגל (כלי עזר)
  Future<void> toggle() async => _isPro ? downgradeToFree() : upgradeToPro();
}
