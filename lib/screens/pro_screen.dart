// lib/screens/pro_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/widgets.dart' as widgets;
import 'package:http/http.dart' as http;
import 'package:timezone/timezone.dart' as tz;

/// PRO - 3 ימים + תקציר לכל יום + "30/100 יום קדימה" (אותה לוגיקת ניקוד כמו בפייתון)
class ProForecastScreen extends StatefulWidget {
  final String birthDate; // yyyy-MM-dd
  final String birthTime; // HH:mm
  final String tz;        // IANA ("Asia/Jerusalem") או "+02:00"
  final String lat;       // "32.08"
  final String lon;       // "34.88"
  final String lang;      // 'he'/'en'

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
  // ---- מצב 3 ימים ----
  bool _loading = true;
  String? _error;
  final List<_DayBundle> _days = [];

  // ---- מצב Tail קדימה ----
  bool _tailLoading = true;
  List<_TailHit> _tail95 = [];
  List<_TailHit> _tail90 = [];

  // =============================================================
  // === תצורה: תוצאות מדויקות (ללא איחוד בכלל) ===
  // =============================================================
  static const int _DEDUPE_MIN = 0;           // 0 = ביטול איחוד חלונות סמוכים (לא בשימוש בפועל)
  static const int _MAX_PER_DAY = 999999;     // אין הגבלת כמות
  static const double _SCORE_95 = 9.75;       // סף 95-100 (כמו בפייתון)
  static const double _SCORE_90 = 9.0;       // סף 90-95 (כמו בפייתון)
  static const int _MAX_URANUS_PER_MIN = 5;   // תקרת תרומת אוראנוס לדקה (לפרסור fallback בלבד)

  // כמה ימים קדימה ל-tail (אפשר 30/60/100 לפי הצורך)
  static const int _DAYS_AHEAD = 30;

  @override
  void initState() {
    super.initState();
    _loadThreeDays();
    _buildTailAhead();
  }

  // =========================
  //       עזרי זמן/אזור זמן
  // =========================

  /// offset לשרת לפי תאריך (נדרש על ידי ה-API). אם IANA - מחשב ב-12:00.
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
      } catch (_) {/* fallback למטה */}
    }
    final dev = DateTime.now().timeZoneOffset;
    final sign = dev.isNegative ? '-' : '+';
    final h = dev.inHours.abs().toString().padLeft(2, '0');
    final m = (dev.inMinutes.abs() % 60).toString().padLeft(2, '0');
    return '$sign$h:$m';
  }

  /// עכשיו באזור הזמן של המשתמש (IANA מדויק כולל DST).
  DateTime _nowInChosenTz() {
    final tzId = widget.tz.trim();
    if (tzId.contains('/')) {
      try {
        final loc = tz.getLocation(tzId);
        return tz.TZDateTime.now(loc);
      } catch (_) {/* המשך */}
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

  /// המרה מדויקת של זמן מקומי (לפי IANA או offset) ל-UTC עבור שעה ספציפית.
  DateTime _localToUtc(String ymd, String hhmm) {
    final d = ymd.split('-').map(int.parse).toList(); // [yyyy,mm,dd]
    final t = hhmm.split(':').map(int.parse).toList(); // [HH,mm]

    if (widget.tz.contains('/')) {
      try {
        final loc = tz.getLocation(widget.tz);
        final local = tz.TZDateTime(loc, d[0], d[1], d[2], t[0], t[1]);
        return local.toUtc();
      } catch (_) {/* fallback */}
    }

    final m = RegExp(r'^([+-])(\d{2}):?(\d{2})$').firstMatch(widget.tz.trim());
    if (m != null) {
      final sign = m.group(1) == '-' ? -1 : 1;
      final h = int.parse(m.group(2)!);
      final mi = int.parse(m.group(3)!);
      final offset = Duration(hours: h, minutes: mi) * sign;
      final localAsUtc = DateTime.utc(d[0], d[1], d[2], t[0], t[1]);
      return localAsUtc.subtract(offset);
    }

    final local = DateTime(d[0], d[1], d[2], t[0], t[1]);
    return local.toUtc();
  }

  List<String> _threeDatesInTz() {
    final fmt = DateFormat('yyyy-MM-dd');
    final nowTz = _nowInChosenTz();
    if (widget.tz.contains('/')) {
      try {
        final loc = tz.getLocation(widget.tz);
        final start = tz.TZDateTime(loc, nowTz.year, nowTz.month, nowTz.day);
        return List.generate(3, (i) => fmt.format(start.add(Duration(days: i))));
      } catch (_) {/* fallback */}
    }
    final start = DateTime(nowTz.year, nowTz.month, nowTz.day);
    return List.generate(3, (i) => fmt.format(start.add(Duration(days: i))));
  }

  // =========================
  //           API
  // =========================

  /// עוזר: לוקח lucky_hours גם מהטופ-לבל וגם מ-days[0] אם צריך
  List _extractLuckyBlocks(Map<String, dynamic> api) {
    final top = (api['lucky_hours'] as List?) ?? const [];
    if (top.isNotEmpty) return top;
    final days = (api['days'] as List?) ?? const [];
    if (days.isNotEmpty && days.first is Map) {
      final d0 = (days.first as Map).cast<String, dynamic>();
      return (d0['lucky_hours'] as List?) ?? const [];
    }
    return const [];
  }

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

    if (Platform.isAndroid || Platform.isIOS) {
      final host = Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';
      final uri = Uri.parse('http://$host:8000/pro_forecast');
      final resp = await http
          .post(uri, headers: const {'Content-Type': 'application/json; charset=utf-8'}, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 90));
      final body = utf8.decode(resp.bodyBytes);
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final parsed = jsonDecode(body);
        if (parsed is Map<String, dynamic>) return parsed;
        return Map<String, dynamic>.from(parsed as Map);
      }
      throw Exception('HTTP ${resp.statusCode}: $body');
    }

    // Desktop (רץ פייתון מקומי)
    final res = await Process.run(
      'python',
      [
        'python/astro_calc_api.py',
        '--date', birthDate,           // אם הסקריפט מצפה לטרנזיט כאן, החלף ל-transitDate
        '--time', birthTime,
        '--lat', lat,
        '--lon', lon,
        '--tz', tzForServer,
        '--lang', lang,
        '--transit-date', transitDate, // פרמטר ייעודי ליום הטרנזיט
      ],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
      environment: const {'PYTHONIOENCODING': 'utf-8'},
      runInShell: true,
    );
    if (res.exitCode != 0) throw Exception('Python error: ${res.stderr}');
    final parsed = jsonDecode(res.stdout as String);
    if (parsed is Map<String, dynamic>) return parsed;
    return Map<String, dynamic>.from(parsed as Map);
  }

  Future<void> _loadThreeDays() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dates = _threeDatesInTz();
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

      // מרכיבים DayBundle + מחשבים tail יומי לכל יום (ללא איחוד)
      final nowUtc = _nowInChosenTz().toUtc();
      final bundles = <_DayBundle>[];
      for (int i = 0; i < results.length; i++) {
        final api = results[i];
        final date = dates[i];
        final bundle = _DayBundle.fromApi(api);

        final dayTail = _extractDayTailForOneDay(
          apiLuckyBlocks: _extractLuckyBlocks(api),
          date: date,
          isToday: i == 0,
          nowUtc: nowUtc,
        );

        bundles.add(bundle.copyWith(
          dayTail95: dayTail.$1,
          dayTail90: dayTail.$2,
        ));
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

  // =========================
  //   ניקוד היבטים (fallback בלבד)
  // =========================
  static const Set<String> _benefics = {'VENUS', 'JUPITER', 'FORTUNE'};

  String _canonPlanet(String s) {
    // הסר סוגריים ותגיות (Natal/Transit/Tr./(n)/(tr) וכו')
    s = s.replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '');
    s = s.replaceAll(RegExp(r'\b(natal|transit|tr\.?|(n|t)r)\b', caseSensitive: false), '');
    s = s.trim();

    final x = s.toLowerCase();
    if (x.contains('venus') || x.contains('ונוס') || x.contains('נוגה') || x.contains('♀')) return 'VENUS';
    if (x.contains('jupiter') || x.contains('יופיט') || x.contains('צדק') || x.contains('♃')) return 'JUPITER';
    if (x.contains('moon') || x.contains('ירח') || x.contains('🌙')) return 'MOON';
    if (x.contains('pluto') || x.contains('פלוטו') || x.contains('♇')) return 'PLUTO';
    if (x.contains('uranus') || x.contains('אוראנוס') || x.contains('אורנוס') || x.contains('♅')) return 'URANUS';
    if (x.contains('fortune') || x.contains('pof') || x.contains('מזל') || x.contains('פורצ׳ון') || x.contains('טבעת המזל') || x.contains('🎯')) return 'FORTUNE';
    if (x.contains('sun') || x.contains('שמש') || x.contains('☉') || x.contains('☀')) return 'SUN';
    if (x.contains('mercury') || x.contains('מרקורי') || x.contains('כוכב חמה') || x.contains('☿')) return 'MERCURY';
    if (x.contains('saturn') || x.contains('סטורן') || x.contains('שבתאי') || x.contains('♄')) return 'SATURN';
    if (x.contains('neptune') || x.contains('נפטון') || x.contains('♆')) return 'NEPTUNE';
    if (x.contains('mars') || x.contains('מאדים') || x.contains('♂')) return 'MARS';
    return s.toUpperCase();
  }

  int _parseAngleFromLine(String line) {
    // תומך: 120°, 120º, 120 deg, “120 מעלות”, וגם מילות היבט
    final mNum = RegExp(r'(\d{1,3})\s*(?:°|º|deg|degrees|מעלות)').firstMatch(line);
    if (mNum != null) {
      final v = int.tryParse(mNum.group(1)!);
      if (v != null) return v.clamp(0, 180);
    }
    final l = line.toLowerCase();
    if (l.contains('trine') || l.contains('טרין') || l.contains('משולש')) return 120;
    if (l.contains('sextile') || l.contains('סקסטיל')) return 60;
    if (l.contains('conj') || l.contains('conjunction') || l.contains('צמידות')) return 0;
    if (l.contains('opp') || l.contains('opposition') || l.contains('אופוזיצ')) return 180;
    return -1;
  }

  _ScoreInfo _scoreFromAspectLines(List<String> lines) {
    double sum = 0.0;
    int uranusUsed = 0;
    bool keyTrine = false;

    double aspectWeight(String p1, String p2, int hAngle) {
      final involvesUranus = (p1 == 'URANUS' || p2 == 'URANUS');
      final beneficInvolved = _benefics.contains(p1) || _benefics.contains(p2);
      if (involvesUranus) {
        if (hAngle == 120) return 2.0;
        if (hAngle == 60)  return 1.0; // ריכוך
        return 0.0;
      }
      if (hAngle == 120) return beneficInvolved ? 2.0 : 1.5;
      if (hAngle == 60)  return beneficInvolved ? 1.0 : 0.5;
      if (hAngle == 0 || hAngle == 180) return beneficInvolved ? 0.5 : 0.0;
      return 0.0;
    }

    for (final line in lines) {
      final parts = line.split('↔');
      if (parts.length != 2) continue;
      final p1 = _canonPlanet(parts[0]);
      final p2 = _canonPlanet(parts[1]);
      final ang = _parseAngleFromLine(line);
      if (ang == -1) continue;

      if (ang == 120 && (_benefics.contains(p1) || _benefics.contains(p2))) {
        keyTrine = true;
      }

      final w = aspectWeight(p1, p2, ang);
      if (w > 0) {
        final involvesUranus = (p1 == 'URANUS' || p2 == 'URANUS');
        if (involvesUranus) {
          if (uranusUsed < _MAX_URANUS_PER_MIN) {
            sum += w;
            uranusUsed += 1;
          }
        } else {
          sum += w;
        }
      }
    }
    return _ScoreInfo(score: sum, keyTrine: keyTrine);
  }

  /// גרסה "מדויקת": ללא איחוד וללא Top-N — מחזירה כל הבלוקים מסודרים כרונולוגית.
  List<_ScoredBlock> _dedupeAndTop(List<_ScoredBlock> list, String date) {
    if (list.isEmpty) return [];
    final withDt = list
        .map((e) => _ScoredWithDt(block: e, dtUtc: _localToUtc(date, e.time)))
        .toList()
      ..sort((a, b) => a.dtUtc.compareTo(b.dtUtc));
    return withDt.map((e) => e.block).toList();
  }

  // =========================
  //   Tail יומי לשלושת הימים
  // =========================
  /// מחזיר (hits95, hits90) עבור יום אחד מתוך lucky_hours — ללא איחוד/הגבלה.
  (List<_TailHit>, List<_TailHit>) _extractDayTailForOneDay({
    required List apiLuckyBlocks,
    required String date,
    required bool isToday,
    required DateTime nowUtc,
  }) {
    final scored = <_ScoredBlock>[];
    for (final raw in apiLuckyBlocks) {
      if (raw is! Map) continue;
      final m = raw.cast<String, dynamic>();

      // תמיכה גם ב-'from' וגם ב-'שעה'
      final from = (m['from'] ?? m['שעה'] ?? '').toString();
      if (from.isEmpty) continue;

      // past times filtering (רק ליום הנוכחי)
      final dtUtc = _localToUtc(date, from);
      if (isToday && !dtUtc.isAfter(nowUtc)) continue;

      // 1) ניקוד מספרי אם יש
      double numScore = -1;
      if (m['score_sum'] is num) {
        numScore = (m['score_sum'] as num).toDouble();
      } else if (m['score_num'] is num) {
        numScore = (m['score_num'] as num).toDouble();
      }

      // 2) תמיד נחשב גם fallback מהטקסט
      final aspects = (m['aspects'] as List? ?? const []).map((x) => x.toString()).toList();
      final info = _scoreFromAspectLines(aspects);
      final textScore = info.score;

      // 3) ניקח את הגבוה
      final score = (numScore >= 0) ? (numScore > textScore ? numScore : textScore) : textScore;

      if (score >= _SCORE_90) {
        scored.add(_ScoredBlock(time: from, score: score));
      }
    }

    final ordered = _dedupeAndTop(scored, date); // רק ממיין; לא ממזג
    final hits95 = <_TailHit>[];
    final hits90 = <_TailHit>[];
    for (final s in ordered) {
      if (s.score >= _SCORE_95) {
        hits95.add(_TailHit(date, s.time));
      } else if (s.score >= _SCORE_90) {
        hits90.add(_TailHit(date, s.time));
      }
    }
    return (hits95, hits90);
  }

  // =========================
  //   Tail קדימה — ללא איחוד/הגבלה
  // =========================
  Future<void> _buildTailAhead() async {
    setState(() => _tailLoading = true);
    try {
      final nowTz = _nowInChosenTz();
      final fmt = DateFormat('yyyy-MM-dd');

      final dates = List.generate(_DAYS_AHEAD, (i) {
        final d = nowTz.add(Duration(days: i));
        if (widget.tz.contains('/')) {
          try {
            final loc = tz.getLocation(widget.tz);
            final start = tz.TZDateTime(loc, d.year, d.month, d.day);
            return fmt.format(start);
          } catch (_) {/* fallback */}
        }
        return fmt.format(DateTime(d.year, d.month, d.day));
      });

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

      final nowUtc = _nowInChosenTz().toUtc();
      final all95 = <_TailHit>[];
      final all90 = <_TailHit>[];

      for (int i = 0; i < responses.length; i++) {
        final api = responses[i];
        final date = dates[i];
        final rawBlocks = _extractLuckyBlocks(api);
        final scored = <_ScoredBlock>[];

        for (final raw in rawBlocks) {
          if (raw is! Map) continue;
          final b = raw.cast<String, dynamic>();

          // תמיכה גם ב-'from' וגם ב-'שעה'
          final from = (b['from'] ?? b['שעה'] ?? '').toString();
          if (from.isEmpty) continue;

          final dtUtc = _localToUtc(date, from);
          if (i == 0 && !dtUtc.isAfter(nowUtc)) continue; // דילוג על עבר היום

          // 1) ניקוד מספרי אם יש
          double numScore = -1;
          if (b['score_sum'] is num) {
            numScore = (b['score_sum'] as num).toDouble();
          } else if (b['score_num'] is num) {
            numScore = (b['score_num'] as num).toDouble();
          }

          // 2) תמיד נחשב גם fallback מהטקסט
          final aspects = (b['aspects'] as List? ?? const []).map((x) => x.toString()).toList();
          final info = _scoreFromAspectLines(aspects);
          final textScore = info.score;

          // 3) הגבוה
          final score = (numScore >= 0) ? (numScore > textScore ? numScore : textScore) : textScore;

          if (score >= _SCORE_90) {
            scored.add(_ScoredBlock(time: from, score: score));
          }
        }

        final ordered = _dedupeAndTop(scored, date); // רק ממיין
        for (final s in ordered) {
          if (s.score >= _SCORE_95) {
            all95.add(_TailHit(date, s.time));
          } else if (s.score >= _SCORE_90) {
            all90.add(_TailHit(date, s.time));
          }
        }
      }

      // מיון כרונולוגי מלא לפי UTC מדויק
      int cmp(_TailHit a, _TailHit b) =>
          _localToUtc(a.date, a.time).compareTo(_localToUtc(b.date, b.time));

      all95.sort(cmp);
      all90.sort(cmp);

      if (!mounted) return;
      setState(() {
        _tail95 = all95;
        _tail90 = all90;
        _tailLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tail95 = [];
        _tail90 = [];
        _tailLoading = false;
      });
    }
  }

  // =========================
  //           UI
  // =========================
  @override
  Widget build(BuildContext context) {
    final header = Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            '📆 תחזית לוטו אסטרולוגית - 3 הימים הקרובים 🎟️',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          SizedBox(height: 6),
        ],
      ),
    );

    final headerWithBirth = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🧬 לפי מפת לידה: ${widget.birthDate} ${widget.birthTime}',
              style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          const Text(
            '🎯 חישוב ניקוד כמו בפייתון (אוראנוס נספר רק ב-120°, 180° לא נספר).',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('🎟️ PRO — 3 ימים + 30/100 יום'),
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
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('שגיאה: $_error', style: const TextStyle(color: Colors.redAccent)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: _days.length + 2, // כותרת + 3 ימים + Tail
                      itemBuilder: (ctx, i) {
                        if (i == 0) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [header, headerWithBirth],
                          );
                        }
                        if (i == _days.length + 1) {
                          return _TailCard(loading: _tailLoading, hits95: _tail95, hits90: _tail90);
                        }
                        final day = _days[i - 1];
                        return _DayCard(bundle: day);
                      },
                    ),
        ),
      ),
    );
  }
}

// =========================
//   מודלים/כרטיסי יום
// =========================
class _DayBundle {
  final String date;               // yyyy-MM-dd
  final List<String> retroPlanets; // ["♄ Saturn ℞", ...]
  final List<_LuckyBlock> blocks;  // רשימת חלונות
  final String? bestHour;          // ההמלצה (שעת שיא לפי כמות היבטים)
  final List<_TailHit> dayTail95;  // תקציר יומי - 95-100
  final List<_TailHit> dayTail90;  // תקציר יומי - 90-95

  _DayBundle({
    required this.date,
    required this.retroPlanets,
    required this.blocks,
    required this.bestHour,
    this.dayTail95 = const [],
    this.dayTail90 = const [],
  });

  _DayBundle copyWith({
    List<_TailHit>? dayTail95,
    List<_TailHit>? dayTail90,
  }) =>
      _DayBundle(
        date: date,
        retroPlanets: retroPlanets,
        blocks: blocks,
        bestHour: bestHour,
        dayTail95: dayTail95 ?? this.dayTail95,
        dayTail90: dayTail90 ?? this.dayTail90,
      );

  factory _DayBundle.fromApi(Map<String, dynamic> api) {
    final date = (api['date'] ?? '').toString();

    final transit = (api['transit'] as Map?)?.cast<String, dynamic>() ?? {};
    final retroFlags = (api['transit_retro_flags'] as Map?)?.cast<String, dynamic>() ?? {};
    final retro = <String>[];
    transit.forEach((label, _) {
      final isRetro = retroFlags[label] == true || label.toString().contains('℞');
      if (isRetro) retro.add(label);
    });

    final blocks = <_LuckyBlock>[];
    final rawBlocks = (api['lucky_hours'] as List?) ?? const [];
    for (final e in rawBlocks) {
      final b = (e as Map).cast<String, dynamic>();
      blocks.add(_LuckyBlock(
        from: ((b['from'] ?? b['שעה']) ?? '').toString(), // תמיכה גם ב-'שעה'
        to: (b['to'] ?? '').toString(),
        scoreLabel: (b['score'] ?? '').toString(),
        aspects: (b['aspects'] as List? ?? const []).map((x) => x.toString()).toList(),
        count: (b['count'] is num)
            ? (b['count'] as num).toInt()
            : (b['aspects'] as List? ?? const []).length,
      ));
    }

    _LuckyBlock? best;
    for (final b in blocks) {
      if (best == null || b.count > best.count) best = b;
    }

    return _DayBundle(
      date: date,
      retroPlanets: retro,
      blocks: blocks,
      bestHour: best?.from,
    );
  }
}

class _LuckyBlock {
  final String from;
  final String to;
  final String scoreLabel; // לדוגמה: "🟢 70-84%"
  final int count;
  final List<String> aspects;

  _LuckyBlock({
    required this.from,
    required this.to,
    required this.scoreLabel,
    required this.count,
    required this.aspects,
  });
}

class _DayCard extends StatelessWidget {
  final _DayBundle bundle;
  const _DayCard({required this.bundle});

  @override
  Widget build(BuildContext context) {
    final dayTitle = "📅 ${bundle.date.replaceAll('-', '/')}";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            Text(dayTitle,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 6),

            if (bundle.retroPlanets.isNotEmpty) ...[
              const Text('🔁 כוכבים בנסיגה:', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 4),
              Text(bundle.retroPlanets.join(', '), style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 10),
            ],

            if (bundle.blocks.isEmpty)
              const Text('❌ אין שעות מזל לוטו ביום זה.', style: TextStyle(color: Colors.white70))
            else
              ...bundle.blocks.map((b) => _blockWidget(b)),

            if (bundle.bestHour != null) ...[
              const SizedBox(height: 8),
              Text('🟢 המלצה: למלא לוטו, חישגד או צ׳אנס סביב ${bundle.bestHour!}',
                  style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w600)),
            ],

            // === תקציר יומי כמו בפייתון ===
            const SizedBox(height: 10),
            const Divider(color: Colors.white24),
            const SizedBox(height: 6),
            const Text('תקציר חזק ליום זה (ניקוד):', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            const Text('✅ 95%-100%:', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w600)),
            if (bundle.dayTail95.isEmpty)
              const Text('(אין)', style: TextStyle(color: Colors.white70))
            else
              ...bundle.dayTail95.map((h) => Text('• ${h.time} - 95%-100%',
                  style: const TextStyle(color: Colors.white))),
            const SizedBox(height: 6),
            const Text('⬆️ 90%-95%:', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w600)),
            if (bundle.dayTail90.isEmpty)
              const Text('(אין)', style: TextStyle(color: Colors.white70))
            else
              ...bundle.dayTail90.map((h) => Text('• ${h.time} - 90%-95%',
                  style: const TextStyle(color: Colors.white))),
          ],
        ),
      ),
    );
  }

  Widget _blockWidget(_LuckyBlock b) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🕐 ${b.from} - 💰 פוטנציאל זכייה: ${b.scoreLabel}', style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 4),
          ...b.aspects.map((line) => Text('• $line', style: const TextStyle(color: Colors.white))).toList(),
        ],
      ),
    );
  }
}

// =========================
//     Tail קדימה – UI
// =========================
class _TailHit {
  final String date; // yyyy-MM-dd
  final String time; // HH:mm
  _TailHit(this.date, this.time);
}

class _TailCard extends StatelessWidget {
  final bool loading;
  final List<_TailHit> hits95;
  final List<_TailHit> hits90;

  const _TailCard({
    required this.loading,
    required this.hits95,
    required this.hits90,
  });

  String _fmt(String ymd, String hhmm) {
    final p = ymd.split('-');
    return '${p[2]}/${p[1]}/${p[0]} $hhmm';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        padding: const EdgeInsets.all(12),
        child: loading
            ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🍀 קדימה - חלונות חזקים (ניקוד):',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 10),
                  const Text('✅ 95%-100%:', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  if (hits95.isEmpty)
                    const Text('(אין)', style: TextStyle(color: Colors.white70))
                  else
                    ...hits95.map((h) => Text('• ${_fmt(h.date, h.time)} - 95%-100%',
                        style: const TextStyle(color: Colors.white))),
                  const SizedBox(height: 10),
                  const Text('⬆️ 90%-95%:', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  if (hits90.isEmpty)
                    const Text('(אין)', style: TextStyle(color: Colors.white70))
                  else
                    ...hits90.map((h) => Text('• ${_fmt(h.date, h.time)} - 90%-95%',
                        style: const TextStyle(color: Colors.white))),
                ],
              ),
      ),
    );
  }
}

// =========================
//      טיפוסים קטנים
// =========================
class _ScoreInfo {
  final double score;
  final bool keyTrine;
  _ScoreInfo({required this.score, required this.keyTrine});
}

class _ScoredBlock {
  final String time;   // HH:mm
  final double score;  // סכום משוקלל
  _ScoredBlock({required this.time, required this.score});
}

class _ScoredWithDt {
  final _ScoredBlock block;
  final DateTime dtUtc;
  _ScoredWithDt({required this.block, required this.dtUtc});
}
