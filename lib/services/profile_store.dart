// lib/services/profile_store.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

class ProfileStore {
  static const _kKey = 'user_profile_v1';

  /// טוען פרופיל שמור (או null אם אין)
  static Future<UserProfile?> loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_kKey);
    if (s == null || s.isEmpty) return null;
    try {
      final m = jsonDecode(s) as Map<String, dynamic>;
      return UserProfile.fromJson(m);
    } catch (_) {
      return null;
    }
  }

  /// שומר את הפרופיל כדאון/JSON בלוקאל־סטורג'
  static Future<void> saveUserProfile(UserProfile p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, jsonEncode(p.toJson()));
  }

  /// ניקוי (אופציונלי, לדיבוג)
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }
}
