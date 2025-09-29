import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/birth_profile.dart';

class BirthProfileStore {
  static const _kKey = 'birth_profile_v1';
  static const _storage = FlutterSecureStorage();

  static Future<void> save(BirthProfile p) async {
    await _storage.write(key: _kKey, value: jsonEncode(p.toJson()));
  }

  static Future<BirthProfile?> load() async {
    final raw = await _storage.read(key: _kKey);
    if (raw == null) return null;
    return BirthProfile.fromJson(jsonDecode(raw));
  }

  static Future<void> clear() => _storage.delete(key: _kKey);
}
