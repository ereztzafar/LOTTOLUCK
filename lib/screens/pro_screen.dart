// lib/screens/pro_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' as widgets;
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

// שימוש בלקוח ה־API עם הדומיין בענן
import 'package:lottoluck/services/api_client.dart';

/// PRO - 3 ימים + תקציר לכל יום + "15/100 יום קדימה"
class ProForecastScreen extends StatefulWidget {
  final String birthDate;
  final String birthTime;
  final String tz;
  final String lat;
  final String lon;
  final String lang;

  const ProForecastScreen({
    super.key,
    required this.birthDate,
    required this.birthTime,
    required this.tz,
    required this.lat,
    required this.lon,
    this.lang = 'he',
  });

  @override
  State<ProForecastScreen> createState() => _ProForecastScreenState();
}

class _ProForecastScreenState extends State<ProForecastScreen> {
  // מצב מסך
  bool _loading = true;
  String? _error;
  final List<_DayBundle> _days = [];

  // Tail קדימה
  bool _tailLoading = true;
  List<_TailHit> _tail95 = [];
  List<_TailHit> _tail90 = [];

  // קבועים
  static const double _SCORE_95 = 9.75;
  static const double _SCORE_90 = 9.0;
  static const int _MAX_URANUS_PER_MIN = 5;
  static const int _DAYS_AHEAD = 15;

  @override
  void initState() {
    super.initState();
    _loadCachedThenRefresh();
  }

  Future<void> _loadCachedThenRefresh() async {
    // קודם מציגים מייד נתונים שמורים (אם קיימים)
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('forecast_cache');
    if (cached != null && mounted) {
      try {
        final parsed = jsonDecode(cached) as Map<String, dynamic>;
        final loadedDays = (parsed['days'] as List?)
                ?.map((e) => _DayBundle.fromApi(Map<String, dynamic>.from(e)))
                .toList() ??
            [];
        setState(() {
          _days
            ..clear()
            ..addAll(loadedDays);
          _tail95 = (parsed['tail95'] as List?)
                  ?.map((e) => _TailHit(e['date'], e['time']))
                  .toList() ??
              [];
          _tail90 = (parsed['tail90'] as List?)
                  ?.map((e) => _TailHit(e['date'], e['time']))
                  .toList() ??
              [];
          _loading = false;
          _tailLoading = false;
        });
      } catch (_) {}
    }

    // טוען נתונים אמיתיים ברקע
    await Future.delayed(const Duration(milliseconds: 200));
    await Future.wait([
      _loadThreeDays(),
      _buildTailAhead(),
    ]);

    // שומר במטמון לתחזית הבאה
    if (_days.isNotEmpty) {
      final data = {
        'days': _days.map((e) => {
              'date': e.date,
              'retro': e.retroPlanets,
              'blocks': e.blocks.map((b) => {
                    'from': b.from,
                    'to': b.to,
                    'score': b.scoreLabel,
                    'aspects': b.aspects,
                    'count': b.count,
                  }),
            }),
        'tail95': _tail95.map((h) => {'date': h.date, 'time': h.time}),
        'tail90': _tail90.map((h) => {'date': h.date, 'time': h.time}),
      };
      await prefs.setString('forecast_cache', jsonEncode(data));
    }
  }

  // ===========
  //  עזרי זמן
  // ===========
  String _tzOffsetForDate(String ymd) {
    final tzId = widget.tz.trim();
    final m1 = RegExp(r'^([+-])(\d{2}):?(\d{2})$').firstMatch(tzId);
    if (m1 != null) return '${m1.group(1)}${m1.group(2)}:${m1.group(3)}';
    if (tzId.contains('/')) {
      try {
        final p = ymd.split('-').map(int.parse).toList();
        final loc = tz.getLocation(tzId);
        final noon = tz.TZDateTime(loc, p[0], p[1], p[2], 12);
        final off = noon.timeZoneOffset;
        final sign = off.isNegative ? '-' : '+';
        final h = off.inHours.abs().toString().padLeft(2, '0');
        final m = (off.inMinutes.abs() % 60).toString().padLeft(2, '0');
        return '$sign$h:$m';
      } catch (_) {}
    }
    final dev = DateTime.now().timeZoneOffset;
    final sign = dev.isNegative ? '-' : '+';
    final h = dev.inHours.abs().toString().padLeft(2, '0');
    final m = (dev.inMinutes.abs() % 60).toString().padLeft(2, '0');
    return '$sign$h:$m';
  }

  DateTime _nowInChosenTz() {
    final tzId = widget.tz.trim();
    if (tzId.contains('/')) {
      try {
        final loc = tz.getLocation(tzId);
        return tz.TZDateTime.now(loc);
      } catch (_) {}
    }
    final m = RegExp(r'^([+-])(\d{2}):?(\d{2})$').firstMatch(tzId);
    if (m != null) {
      final sign = m.group(1) == '-' ? -1 : 1;
      final h = int.parse(m.group(2)!);
      final mi = int.parse(m.group(3)!);
      return DateTime.now().toUtc().add(Duration(hours: h, minutes: mi) * sign);
    }
    return DateTime.now();
  }

  DateTime _localToUtc(String ymd, String hhmm) {
    final d = ymd.split('-').map(int.parse).toList();
    final t = hhmm.split(':').map(int.parse).toList();
    if (widget.tz.contains('/')) {
      try {
        final loc = tz.getLocation(widget.tz);
        final local = tz.TZDateTime(loc, d[0], d[1], d[2], t[0], t[1]);
        return local.toUtc();
      } catch (_) {}
    }
    return DateTime.utc(d[0], d[1], d[2], t[0], t[1]);
  }

  // ===========
  //   API
  // ===========
  Future<Map<String, dynamic>> _runApi({
    required String transitDate,
    required String birthDate,
    required String birthTime,
    required String tzStr,
    required String lat,
    required String lon,
    required String lang,
  }) async {
    final tzForServer = _tzOffsetForDate(transitDate);
    final payload = {
      'transit_date': transitDate,
      'birth_date': birthDate,
      'birth_time': birthTime,
      'tz': tzForServer,
      'lat': lat,
      'lon': lon,
      'lang': lang,
    };

    final resp = await http
        .post(
          Api.pro(),
          headers: const {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 90));

    final body = utf8.decode(resp.bodyBytes);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(body);
    }
    throw Exception('HTTP ${resp.statusCode}: $body');
  }

  Future<void> _loadThreeDays() async {
    try {
      final dates = List.generate(3, (i) {
        final now = _nowInChosenTz();
        final d = now.add(Duration(days: i));
        return DateFormat('yyyy-MM-dd').format(d);
      });
      final results = await Future.wait(dates.map((d) {
        return _runApi(
          transitDate: d,
          birthDate: widget.birthDate,
          birthTime: widget.birthTime,
          tzStr: widget.tz,
          lat: widget.lat,
          lon: widget.lon,
          lang: widget.lang,
        );
      }));

      final bundles = <_DayBundle>[];
      for (int i = 0; i < results.length; i++) {
        final api = results[i];
        final bundle = _DayBundle.fromApi(api);
        bundles.add(bundle);
      }

      if (!mounted) return;
      setState(() {
        _days
          ..clear()
          ..addAll(bundles);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _buildTailAhead() async {
    try {
      final nowTz = _nowInChosenTz();
      final fmt = DateFormat('yyyy-MM-dd');
      final dates = List.generate(_DAYS_AHEAD, (i) => fmt.format(nowTz.add(Duration(days: i))));
      final responses = await Future.wait(dates.map((d) {
        return _runApi(
          transitDate: d,
          birthDate: widget.birthDate,
          birthTime: widget.birthTime,
          tzStr: widget.tz,
          lat: widget.lat,
          lon: widget.lon,
          lang: widget.lang,
        );
      }));

      final all95 = <_TailHit>[];
      final all90 = <_TailHit>[];
      for (int i = 0; i < responses.length; i++) {
        final api = responses[i];
        final rawBlocks = (api['lucky_hours'] as List?) ?? [];
        for (final b in rawBlocks) {
          if (b is! Map) continue;
          final score = (b['score_sum'] ?? 0).toDouble();
          final from = (b['from'] ?? b['שעה'] ?? '').toString();
          if (score >= _SCORE_95) all95.add(_TailHit(dates[i], from));
          else if (score >= _SCORE_90) all90.add(_TailHit(dates[i], from));
        }
      }

      if (!mounted) return;
      setState(() {
        _tail95 = all95;
        _tail90 = all90;
        _tailLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _tailLoading = false);
    }
  }

  // ===========
  //    UI
  // ===========
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎟️ PRO — תחזית לוטו'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF5B2C98), Color(0xFF0D0D0D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black, Colors.deepPurple],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Directionality(
          textDirection: widgets.TextDirection.rtl,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Text('שגיאה: $_error', style: const TextStyle(color: Colors.redAccent)))
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        const Text(
                          '📆 תחזית לוטו אסטרולוגית ל-3 הימים הקרובים 🎟️',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        ..._days.map((d) => _DayCard(bundle: d)),
                        _TailCard(loading: _tailLoading, hits95: _tail95, hits90: _tail90),
                      ],
                    ),
        ),
      ),
    );
  }
}

// ======================================================
//     מודלים ותצוגות (DayBundle / TailCard / DayCard)
// ======================================================
class _DayBundle {
  final String date;
  final List<String> retroPlanets;
  final List<_LuckyBlock> blocks;
  final String? bestHour;

  _DayBundle({
    required this.date,
    required this.retroPlanets,
    required this.blocks,
    required this.bestHour,
  });

  factory _DayBundle.fromApi(Map<String, dynamic> api) {
    final date = (api['date'] ?? '').toString();
    final retro = (api['transit_retro_flags'] as Map?)?.keys.map((e) => e.toString()).toList() ?? [];
    final rawBlocks = (api['lucky_hours'] as List?) ?? [];
    final blocks = rawBlocks.map((e) {
      final m = (e as Map).cast<String, dynamic>();
      return _LuckyBlock(
        from: (m['from'] ?? m['שעה'] ?? '').toString(),
        to: (m['to'] ?? '').toString(),
        scoreLabel: (m['score'] ?? '').toString(),
        aspects: (m['aspects'] as List?)?.map((x) => x.toString()).toList() ?? [],
        count: (m['count'] is num)
            ? (m['count'] as num).toInt()
            : ((m['aspects'] as List?)?.length ?? 0),
      );
    }).toList();
    String? best;
    if (blocks.isNotEmpty) {
      blocks.sort((a, b) => b.count.compareTo(a.count));
      best = blocks.first.from;
    }
    return _DayBundle(date: date, retroPlanets: retro, blocks: blocks, bestHour: best);
  }
}

class _LuckyBlock {
  final String from;
  final String to;
  final String scoreLabel;
  final int count;
  final List<String> aspects;
  _LuckyBlock({required this.from, required this.to, required this.scoreLabel, required this.count, required this.aspects});
}

class _TailHit {
  final String date;
  final String time;
  _TailHit(this.date, this.time);
}

class _DayCard extends StatelessWidget {
  final _DayBundle bundle;
  const _DayCard({required this.bundle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("📅 ${bundle.date.replaceAll('-', '/')}",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            if (bundle.retroPlanets.isNotEmpty)
              Text('🔁 כוכבים בנסיגה: ${bundle.retroPlanets.join(', ')}',
                  style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            ...bundle.blocks.map((b) => Text('🕐 ${b.from} - 💰 ${b.scoreLabel}',
                style: const TextStyle(color: Colors.white))),
            if (bundle.bestHour != null)
              Text('🟢 שעה מומלצת: ${bundle.bestHour!}',
                  style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _TailCard extends StatelessWidget {
  final bool loading;
  final List<_TailHit> hits95;
  final List<_TailHit> hits90;
  const _TailCard({required this.loading, required this.hits95, required this.hits90});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        padding: const EdgeInsets.all(12),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🍀 15 הימים הקרובים:',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text('✅ 95%-100%:', style: TextStyle(color: Colors.greenAccent)),
                  ...hits95.map((h) =>
                      Text('• ${h.date.replaceAll('-', '/')} ${h.time}', style: const TextStyle(color: Colors.white))),
                  const SizedBox(height: 6),
                  const Text('⬆️ 90%-95%:', style: TextStyle(color: Colors.amber)),
                  ...hits90.map((h) =>
                      Text('• ${h.date.replaceAll('-', '/')} ${h.time}', style: const TextStyle(color: Colors.white))),
                ],
              ),
      ),
    );
  }
}
