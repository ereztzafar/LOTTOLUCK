// FILE: lib/screens/forecast_screen.dart
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../widgets/astro_wheel.dart';
import 'package:timezone/timezone.dart' as tz;
import '../services/asc_mc.dart';

class ForecastScreen extends StatefulWidget {
  final Map<String, dynamic> forecastData;
  final String birthDate; // 'yyyy-MM-dd'
  final String birthTime; // 'HH:mm'
  final String tz;        // IANA, e.g. 'Asia/Jerusalem'
  final String lat;       // stringified double
  final String lon;       // stringified double

  const ForecastScreen({
    super.key,
    required this.forecastData,
    required this.birthDate,
    required this.birthTime,
    required this.tz,
    required this.lat,
    required this.lon,
  });

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  bool showAllAspects = false;

  /// ==== Aliases (מיפוי שם → שם קנוני) ====
  /// המפתחות כאן אחרי נירמול (ראו _normalizeKey): גם עברית, גם אנגלית וגם גליפים.
  static const Map<String, String> aliases = {
    // Planets – English
    'sun': 'Sun', 'moon': 'Moon', 'mercury': 'Mercury', 'venus': 'Venus',
    'mars': 'Mars', 'jupiter': 'Jupiter', 'saturn': 'Saturn',
    'uranus': 'Uranus', 'neptune': 'Neptune', 'pluto': 'Pluto',
    'node': 'Node', 'northnode': 'Node', 'truenode': 'Node', 'meannode': 'Node',
    'southnode': 'South Node',

    // Planets – Hebrew (כולל כמה כינויים נפוצים)
    'שמש': 'Sun',
    'ירח': 'Moon',
    'מרקורי': 'Mercury', 'כוכבחמה': 'Mercury',
    'ונוס': 'Venus', 'נוגה': 'Venus',
    'מאדים': 'Mars',
    'יופיטר': 'Jupiter', 'צדק': 'Jupiter',
    'סטורן': 'Saturn', 'שבתאי': 'Saturn',
    'אורנוס': 'Uranus',
    'נפטון': 'Neptune',
    'פלוטו': 'Pluto',
    'ראשדרקון': 'Node',
    'זנבהדרקון': 'South Node',

    // Glyphs
    '☉': 'Sun', '☽': 'Moon', '☿': 'Mercury', '♀': 'Venus', '♂': 'Mars',
    '♃': 'Jupiter', '♄': 'Saturn', '♅': 'Uranus', '♆': 'Neptune', '♇': 'Pluto',
    '☊': 'Node', '☋': 'South Node',

    // Axes
    'asc': 'ASC', 'mc': 'MC',
  };

  // ===== Retro/helpers =====

  // מזהה ℞ או R גם כשיש סימני פיסוק ליד ה-R (למשל R), R:, R;)
  bool _isRetro(String s) {
    if (s.isEmpty) return false;
    final t = s.replaceAll('\u200f', '').replaceAll('\u200e', '');
    if (t.contains('℞')) return true;
    final re = RegExp(r'(^|[\s\(])R(?=$|[\s\)\:\,\;\.])', caseSensitive: false);
    return re.hasMatch(t);
  }

  String _cleanRetro(String s) => s
      .replaceAll('\u200f', '')
      .replaceAll('\u200e', '')
      .replaceAll('℞', '')
      .replaceAll(RegExp(r'(^|[\s\(])R(?=$|[\s\)\:\,\;\.])', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  // “truthy” כללי לדגלים שמגיעים כטקסט/מספר/בוליאן
  bool _isTruthy(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().trim().toLowerCase();
    return s == 'true' || s == 'r' || s == 'retro' || s == 'yes' || s == 'y' || s == '1';
  }

  // תגית R לשימוש חוזר
  Widget _rTag(Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          border: Border.all(color: c, width: 1.3),
          borderRadius: BorderRadius.circular(4),
          color: c.withOpacity(0.10),
        ),
        child: Text(
          'R',
          style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 11.5, height: 1.1),
        ),
      );

  Widget _planetLine(String label, String value, {Color rColor = Colors.orangeAccent}) {
    final retro = _isRetro(label) || _isRetro(value);
    final cleanVal = _cleanRetro(value);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white, height: 1.35),
          children: [
            TextSpan(text: label.replaceAll('℞', '')),
            if (retro) const TextSpan(text: ' '),
            if (retro)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: _rTag(rColor),
              ),
            const TextSpan(text: ': '),
            TextSpan(text: cleanVal),
          ],
        ),
      ),
    );
  }

  // ===== Parsing helpers =====
  static const Map<String, int> _signIndex = {
    'Aries': 0, 'Taurus': 1, 'Gemini': 2, 'Cancer': 3, 'Leo': 4, 'Virgo': 5,
    'Libra': 6, 'Scorpio': 7, 'Sagittarius': 8, 'Capricorn': 9, 'Aquarius': 10, 'Pisces': 11,
    'טלה': 0, 'שור': 1, 'תאומים': 2, 'סרטן': 3, 'אריה': 4, 'בתולה': 5,
    'מאזניים': 6, 'עקרב': 7, 'קשת': 8, 'גדי': 9, 'דלי': 10, 'דגים': 11,
  };

  double? _parseSignPosToDeg(String raw) {
    final s = raw.replaceAll('\u200f', '').replaceAll('\u200e', '').trim();
    final re = RegExp(
      r'([A-Za-z\u0590-\u05FF]+)\s+(\d{1,2})(?:[°\s]+(\d{1,2}))?(?:[\'′]\s*(\d{1,2}))?'
    );
    final m = re.firstMatch(s);
    if (m == null) return null;

    final sign = m.group(1)!.trim();
    final deg  = int.tryParse(m.group(2) ?? '0') ?? 0;
    final min  = int.tryParse(m.group(3) ?? '0') ?? 0;
    final sec  = int.tryParse(m.group(4) ?? '0') ?? 0;

    final si = _signIndex.entries.firstWhere(
      (e) => e.key.toLowerCase() == sign.toLowerCase(),
      orElse: () => const MapEntry('', -1),
    ).value;
    if (si == -1) return null;

    return si * 30 + deg + (min / 60.0) + (sec / 3600.0);
  }

  double? _tryNum(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.'));
    return null;
  }

  // נירמול קשוח של מפתחות
  String _normalizeKey(String k) {
    var s = k.replaceAll('\u200f', '').replaceAll('\u200e', '');
    s = s.replaceAll(RegExp(r'\(.*?\)'), ''); // remove ( ... )
    s = s.replaceAll(RegExp(r'[^A-Za-z\u0590-\u05FF☉☽☿♀♂♃♄♅♆♇☊☋]'), '');
    s = s.toLowerCase().trim();
    return s;
  }

  String? _canonPlanetName(String k) {
    final cleanK = k.replaceAll('(', '').replaceAll(')', '').trim();

    // נסה כל חלק בנפרד – “♀” ואז “Venus” וכו'
    final parts = cleanK.split(RegExp(r'\s+'));
    for (final part in parts) {
      final n = _normalizeKey(part);
      if (n.isNotEmpty && aliases.containsKey(n)) return aliases[n];
    }

    // נסה על המחרוזת המלאה לאחר נירמול
    final fullNormalized = _normalizeKey(cleanK);
    if (aliases.containsKey(fullNormalized)) return aliases[fullNormalized];

    return null;
  }

  // גליף לפי שם קנוני (לרשימת היבטים)
  String? _glyphForCanon(String canon) {
    switch (canon) {
      case 'Sun': return '☉';
      case 'Moon': return '☽';
      case 'Mercury': return '☿';
      case 'Venus': return '♀';
      case 'Mars': return '♂';
      case 'Jupiter': return '♃';
      case 'Saturn': return '♄';
      case 'Uranus': return '♅';
      case 'Neptune': return '♆';
      case 'Pluto': return '♇';
      case 'Node': return '☊';
      case 'South Node': return '☋';
      default: return null;
    }
  }

  double? _parseLonAny(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    return _tryNum(s) ?? _parseSignPosToDeg(s);
  }

  bool _retroFrom(dynamic v) => _isRetro(v?.toString() ?? '');

  // ===== בונה מפות רטרו מחוזקות (מאחד flags + סריקת טקסטים) =====
  Map<String, bool> _retroUnion(Map? flags, Map? valuesMap) {
    final out = <String, bool>{};
    void put(String raw) {
      final canon = _canonPlanetName(raw);
      if (canon != null) {
        out[canon] = true;
        out[_normalizeKey(canon)] = true;
      }
    }
    if (flags is Map) {
      flags.forEach((k, v) {
        if (_isTruthy(v)) put(k.toString());
      });
    }
    if (valuesMap is Map) {
      valuesMap.forEach((k, v) {
        final ks = k.toString(), vs = v?.toString() ?? '';
        if (_isRetro(ks) || _isRetro(vs)) put(_cleanRetro(ks));
      });
    }
    return out;
  }

  bool _retroLookup(Map<String,bool> retroMap, String planetLabel, {String? posText, dynamic explicitFlag}) {
    // 1) שדה מפורש מהשרת
    if (_isTruthy(explicitFlag)) return true;

    // 2) ישירות מהטקסט של הכוכב/המיקום
    if (_isRetro(planetLabel) || (posText != null && _isRetro(posText))) return true;

    // 3) מהמפה המאוחדת, עם כל הוריאציות
    final c1 = _canonPlanetName(_cleanRetro(planetLabel));
    if (c1 != null && (retroMap[c1] == true || retroMap[_normalizeKey(c1)] == true)) return true;

    final c2 = _canonPlanetName(planetLabel);
    if (c2 != null && (retroMap[c2] == true || retroMap[_normalizeKey(c2)] == true)) return true;

    return false;
  }

  // ===== Build ChartData =====
  ChartData? _buildChartData(Map<String, dynamic> f) {
    final natal   = (f['natal']   as Map?)?.cast<String, dynamic>() ?? {};
    final transit = (f['transit'] as Map?)?.cast<String, dynamic>() ?? {};

    // ASC/MC חישוב מקומי
    final tzLoc = tz.getLocation(widget.tz);
    final d = widget.birthDate.split('-'); // yyyy-MM-dd
    final t = widget.birthTime.split(':'); // HH:mm
    final localDT = tz.TZDateTime(
      tzLoc,
      int.parse(d[0]), int.parse(d[1]), int.parse(d[2]),
      int.parse(t[0]), int.parse(t[1]),
    );
    final utcDT = localDT.toUtc();

    final lat = double.tryParse(widget.lat) ?? 0.0;
    final lon = double.tryParse(widget.lon) ?? 0.0;

    final am = AscMc.compute(utc: utcDT, latitude: lat, longitude: lon);
    final double ascDeg = am.ascDeg;
    final double? mcDeg = am.mcDeg;

    // בתים אם נשלחו מהשרת
    List<double>? houses;
    for (final key in ['natal_house_deg', 'natal_houses_deg', 'houses_deg', 'house_deg']) {
      final raw = f[key];
      if (raw is List && raw.length >= 12) {
        houses = raw.take(12).map((e) => _tryNum(e) ?? 0.0).toList();
        break;
      }
    }

    final natalPlanets = <PlanetPos>[];
    final transitPlanets = <PlanetPos>[];

    void addAllFrom(Map<String, dynamic> src, {required bool isTransit}) {
      src.forEach((k, v) {
        final c = _canonPlanetName(k);
        if (c == null) return;
        if (c == 'ASC' || c == 'MC') return; // צירים מצוירים בנפרד
        final lonDeg = _parseLonAny(v);
        if (lonDeg == null) return;

        final rf = (isTransit ? f['transit_retro_flags'] : f['natal_retro_flags']);
        bool retroFlag = false;
        if (rf is Map) {
          final nk = _normalizeKey(k);
          retroFlag = _isTruthy(rf[k]) || _isTruthy(rf[c]) || _isTruthy(rf[nk]);
        }

        (isTransit ? transitPlanets : natalPlanets).add(
          PlanetPos(
            name: c,
            lon: lonDeg,
            retro: retroFlag || _retroFrom(v),
            isTransit: isTransit,
          ),
        );
      });
    }

    addAllFrom(natal, isTransit: false);
    addAllFrom(transit, isTransit: true);

    // אספקטים למרכז הגלגל (אם רוצים לצייר שם קווים)
    final aspects = <AspectHit>[];
    final rawAspects = (f['aspects'] as List?) ?? [];
    for (final raw in rawAspects) {
      if (raw is! Map) continue;
      final a = raw.cast<String, dynamic>();

      String clean(String s) => _cleanRetro(s);
      final tName = _canonPlanetName(clean((a['tPlanet'] ?? '').toString()));
      final nName = _canonPlanetName(clean((a['nPlanet'] ?? '').toString()));
      final tLon  = _parseLonAny(a['tPos']);
      final nLon  = _parseLonAny(a['nPos']);
      if (tName == null || nName == null || tLon == null || nLon == null) continue;

      aspects.add(AspectHit(
        aName: tName, aLon: tLon,
        bName: nName, bLon: nLon,
        label: (a['aspect'] ?? '').toString(),
      ));
    }

    if (kDebugMode) {
      debugPrint('★ natalPlanets=${natalPlanets.length}   transitPlanets=${transitPlanets.length}');
      if (natalPlanets.isNotEmpty) {
        debugPrint('  natal sample: ${natalPlanets.take(5).map((p) => '${p.name}@${p.lon.toStringAsFixed(2)}').join(', ')}');
      }
      if (transitPlanets.isNotEmpty) {
        debugPrint('  transit sample: ${transitPlanets.take(5).map((p) => '${p.name}@${p.lon.toStringAsFixed(2)}').join(', ')}');
      }
    }

    return ChartData(
      ascDeg: ascDeg,
      mcDeg: mcDeg,
      houseCusps: houses,
      planetsNatal: natalPlanets,
      planetsTransit: transitPlanets,
      aspects: aspects,
      zodiacInnerFactor: 0.80,
      zodiacOuterFactor: 0.88,
      aspectRadiusFactor: 0.34,
      aspectStrokeFactor: 0.005,
      rotationCCWDeg: 0.0,
      showAscBadge: true,
      houseSystem: HouseSystem.placidus,
    );
  }

  // ===== UI helpers =====
  Widget _title(String s, Color c) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(s, style: TextStyle(color: c, fontWeight: FontWeight.w700)),
      );

  Widget _card({required Widget child}) => Container(
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        padding: const EdgeInsets.all(12),
        child: child,
      );

  Widget _leftSummaryPanel(Map<String, dynamic> natal, Map<String, dynamic> transit) {
    return _card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _title('✨ לידה', Colors.amber),
                if (natal.isEmpty)
                  const Text('-', style: TextStyle(color: Colors.white54))
                else
                  ...natal.entries.map(
                    (e) => _planetLine(e.key, e.value.toString(), rColor: Colors.amber),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _title('🚀 טרנזיט (עכשיו)', Colors.lightBlueAccent),
                if (transit.isEmpty)
                  const Text('-', style: TextStyle(color: Colors.white54))
                else
                  ...transit.entries.map(
                    (e) => _planetLine(e.key, e.value.toString(), rColor: Colors.lightBlueAccent),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // גליף צבוע + שם כוכב (לרשימת היבטים)
  List<InlineSpan> _styledPlanetNameSpan({
    required String rawLabel,
    required bool isTransit,
    required bool isRetro,
  }) {
    final canon = _canonPlanetName(rawLabel) ?? rawLabel;
    final glyph = _glyphForCanon(canon);
    final after = _cleanRetro(rawLabel).replaceAll(RegExp(r'^[☉☽☿♀♂♃♄♅♆♇☊☋]\s*'), '');
    final color = isTransit ? Colors.lightBlueAccent : Colors.greenAccent;

    return [
      if (glyph != null)
        TextSpan(text: glyph, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
      if (glyph != null && after.isNotEmpty) const TextSpan(text: ' '),
      TextSpan(text: after, style: const TextStyle(color: Colors.white)),
      if (isRetro) const WidgetSpan(child: SizedBox(width: 4)),
      if (isRetro)
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _rTag(isTransit ? Colors.lightBlueAccent : Colors.greenAccent),
        ),
    ];
  }

  // צבע לטקסט סוג ההיבט
  Color _aspectColor(String asp) {
    final a = asp.toLowerCase();
    if (a.contains('conjunction') || a.contains('צמיד')) return Colors.amberAccent;
    if (a.contains('opposition') || a.contains('אופוז')) return Colors.orangeAccent;
    if (a.contains('square') || a.contains('ריבוע')) return Colors.redAccent;
    if (a.contains('trine') || a.contains('משולש') || a.contains('טרין')) return Colors.blueAccent;
    if (a.contains('sextile') || a.contains('שיש')) return Colors.tealAccent;
    return Colors.white70;
  }

  Widget _aspectsList(List aspects) {
    if (aspects.isEmpty) {
      return _card(
        child: const Text('אין היבטים בטווח האורב שהוגדר.', style: TextStyle(color: Colors.white70)),
      );
    }

    // מפות רטרו מאוחדות (מ-flags + טקסט המפות)
    final Map<String, dynamic> natalMap  =
        (widget.forecastData['natal']  as Map?)?.cast<String, dynamic>() ?? {};
    final Map<String, dynamic> transitMap=
        (widget.forecastData['transit']as Map?)?.cast<String, dynamic>() ?? {};
    final retroNatal   = _retroUnion(widget.forecastData['natal_retro_flags'],   natalMap);
    final retroTransit = _retroUnion(widget.forecastData['transit_retro_flags'], transitMap);

    const int limit = 8;
    final int count = showAllAspects ? aspects.length : math.min(aspects.length, limit);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => setState(() => showAllAspects = !showAllAspects),
              icon: Icon(showAllAspects ? Icons.expand_less : Icons.expand_more, size: 18, color: Colors.white70),
              label: Text(
                showAllAspects ? 'הצג פחות' : 'הצג את כל ${aspects.length} ההיבטים',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ),
          const SizedBox(height: 4),
          ListView.separated(
            shrinkWrap: true,
            primary: false,
            itemCount: count,
            separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 12),
            itemBuilder: (_, i) {
              final a = (aspects[i] as Map).cast<String, dynamic>();

              final String rawTPlanet = (a['tPlanet'] ?? '').toString();
              final String rawNPlanet = (a['nPlanet'] ?? '').toString();
              final String rawTPos    = (a['tPos'] ?? '').toString();
              final String rawNPos    = (a['nPos'] ?? '').toString();

              final String tPos = _cleanRetro(rawTPos);
              final String nPos = _cleanRetro(rawNPos);

              final String aspect = (a['aspect'] ?? '').toString();
              final String orb    = (a['orb'] ?? '').toString();

              // רטרו חזק: lookup מאוחד
              final bool tRetro = _retroLookup(retroTransit, rawTPlanet, posText: rawTPos, explicitFlag: a['tRetro']);
              final bool nRetro = _retroLookup(retroNatal , rawNPlanet, posText: rawNPos, explicitFlag: a['nRetro']);

              if (kDebugMode && i < 3) {
                debugPrint('[ASPECT $i] ${_cleanRetro(rawTPlanet)}  $aspect  ${_cleanRetro(rawNPlanet)}  '
                    '=> tRetro=$tRetro | nRetro=$nRetro');
              }

              return RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.white, height: 1.5),
                  children: [
                    const TextSpan(text: '• '),

                    ..._styledPlanetNameSpan(
                      rawLabel: rawTPlanet,
                      isTransit: true,
                      isRetro: tRetro,
                    ),

                    const TextSpan(text: ' (', style: TextStyle(color: Colors.white70)),
                    TextSpan(text: tPos, style: const TextStyle(color: Colors.white70)),
                    const TextSpan(text: ') — ', style: const TextStyle(color: Colors.white70)),

                    TextSpan(
                      text: aspect,
                      style: TextStyle(color: _aspectColor(aspect), fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: ' ($orb°) — ', style: const TextStyle(color: Colors.white70)),

                    ..._styledPlanetNameSpan(
                      rawLabel: rawNPlanet,
                      isTransit: false, // natal
                      isRetro: nRetro,
                    ),

                    const TextSpan(text: ' (', style: TextStyle(color: Colors.white70)),
                    TextSpan(text: nPos, style: const TextStyle(color: Colors.white70)),
                    const TextSpan(text: ')'),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _wheelCard() {
    final chart = _buildChartData(widget.forecastData);
    if (chart == null) {
      return _card(
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, color: Colors.white70),
              SizedBox(height: 8),
              Text('תצוגת גלגל אינה זמינה לנתונים אלה.', style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    final noPlanets = chart.planetsNatal.isEmpty && chart.planetsTransit.isEmpty;

    return _card(
      child: Column(
        children: [
          Center(
            child: AstroWheel(
              data: chart,
              size: 420,
              fontScale: 1.05,
            ),
          ),
          if (noPlanets)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'לא התקבלו מיקומי כוכבים מהנתונים - בדוק את מפתחות ה-JSON/שמות הכוכבים.',
                style: TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> natal =
        (widget.forecastData['natal'] as Map?)?.cast<String, dynamic>() ?? {};
    final Map<String, dynamic> transit =
        (widget.forecastData['transit'] as Map?)?.cast<String, dynamic>() ?? {};
    final List<dynamic> aspects =
        (widget.forecastData['aspects'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text('🔮 תחזית יומית   •   ${widget.forecastData['date'] ?? ''}'),
        backgroundColor: Colors.deepPurple.shade700,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black, Colors.deepPurple],
            begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, cs) {
            final bool wide = cs.maxWidth >= 1100;

            if (!wide) {
              return ListView(
                children: [
                  Center(
                    child: Text(
                      '🗓️ תאריך: ${widget.forecastData['date'] ?? ''}',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _leftSummaryPanel(natal, transit),
                  const SizedBox(height: 12),
                  // רשימת היבטים נגללת
                  SingleChildScrollView(child: _aspectsList(aspects)),
                  const SizedBox(height: 12),
                  _wheelCard(),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      Center(
                        child: Text(
                          '🗓️ תאריך: ${widget.forecastData['date'] ?? ''}',
                          style: const TextStyle(color: Colors.white, fontSize: 20),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _leftSummaryPanel(natal, transit),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  flex: 2,
                  // רשימת היבטים נגללת
                  child: SingleChildScrollView(child: _aspectsList(aspects)),
                ),
                const SizedBox(width: 18),
                Expanded(
                  flex: 3,
                  child: Align(alignment: Alignment.topRight, child: _wheelCard()),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
