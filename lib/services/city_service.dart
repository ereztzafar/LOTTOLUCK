// lib/services/city_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';

class CityRow {
  final String city;
  final String country;
  final double lat;
  final double lon;
  final String? tz;
  const CityRow({required this.city, required this.country, required this.lat, required this.lon, this.tz});
}

class CityService {
  CityService._();
  static final CityService I = CityService._();

  bool _loaded = false;
  List<CityRow> _all = [];

  int get count => _all.length;

  Future<void> warmUp() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString('assets/worldcities.csv'); // בדיוק כמו ב pubspec
      final rows = const CsvToListConverter(shouldParseNumbers: false).convert(raw);
      if (rows.isEmpty) throw Exception('worldcities.csv is empty');

      final header = rows.first.map((e) => '$e').toList();
      int idxOf(List<String> names) {
        for (final n in names) {
          final i = header.indexWhere((h) => h.trim().toLowerCase() == n.trim().toLowerCase());
          if (i >= 0) return i;
        }
        return -1;
      }

      final iCity    = idxOf(['city', 'name']);
      final iCountry = idxOf(['country', 'country_name']);
      final iLat     = idxOf(['lat', 'latitude']);
      final iLon     = idxOf(['lng', 'lon', 'longitude']);
      final iTz      = idxOf(['timezone', 'tz', 'time_zone', 'iana_tz']);

      if (iCity < 0 || iCountry < 0 || iLat < 0 || iLon < 0) {
        throw Exception('Required columns not found: city,country,lat,lon');
      }

      final list = <CityRow>[];
      for (var i = 1; i < rows.length; i++) {
        final r = rows[i];
        String getStr(int idx) => (idx >= 0 && idx < r.length) ? '${r[idx]}'.trim() : '';
        double toD(String s) => double.tryParse(s) ?? 0.0;

        final city = getStr(iCity);
        final country = getStr(iCountry);
        if (city.isEmpty || country.isEmpty) continue;

        list.add(CityRow(
          city: city,
          country: country,
          lat: toD(getStr(iLat)),
          lon: toD(getStr(iLon)),
          tz: iTz >= 0 ? getStr(iTz) : null,
        ));
      }

      _all = list;
      _loaded = true;
      debugPrint('CityService: loaded ${_all.length} cities');
    } catch (e, st) {
      _loaded = true;
      _all = [];
      debugPrint('CityService: load failed: $e\n$st');
      rethrow;
    }
  }

  Future<List<CityRow>> search(String query, {int limit = 20}) async {
    await warmUp();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _all.take(10).toList(); // הצעות פתיחה
    return _all.where((c) => c.city.toLowerCase().contains(q)).take(limit).toList();
  }
}
