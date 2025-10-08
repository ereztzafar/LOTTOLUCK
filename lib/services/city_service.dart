// lib/services/city_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';

class CityRow {
  final String city;
  final String country;
  CityRow(this.city, this.country);
}

class CityService {
  CityService._();
  static final CityService I = CityService._();

  bool _loaded = false;
  final List<CityRow> _all = [];
  final List<String> _allNames = [];

  bool get isLoaded => _loaded;
  int get count => _all.length;

  Future<void> warmUp() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString('assets/worldcities.csv'); // נתיב מדויק
      final rows = const CsvToListConverter(
        shouldParseNumbers: false,
        eol: '\n',
      ).convert(raw);

      if (rows.isEmpty) throw Exception('CSV is empty');
      final header = rows.first.map((e) => '$e').toList();
      final idxCity = header.indexOf('city');
      final idxCountry = header.indexOf('country');
      if (idxCity < 0 || idxCountry < 0) {
        throw Exception('Required columns not found: city,country');
      }

      for (var i = 1; i < rows.length; i++) {
        final r = rows[i];
        final city = '${r[idxCity]}';
        final country = '${r[idxCountry]}';
        if (city.isEmpty) continue;
        _all.add(CityRow(city, country));
        _allNames.add(city);
      }
      _loaded = true;
      debugPrint('CityService: loaded ${_all.length} rows');
    } catch (e, st) {
      _loaded = true; // מונע לולאה אינסופית
      debugPrint('CityService: load failed: $e\n$st');
      rethrow;
    }
  }

  // סינון מסונכרן לשימוש עם Autocomplete
  Iterable<String> filterSync(String query, {int limit = 20}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _allNames.take(10); // הצעות פתיחה
    return _allNames.where((s) => s.toLowerCase().contains(q)).take(limit);
  }
}
