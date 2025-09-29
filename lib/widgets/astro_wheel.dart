// lib/widgets/astro_wheel.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// =======================================================
/// Public Models
/// =======================================================

enum HouseSystem { equal, wholeSign, placidus }

class PlanetPos {
  final String name;      // Sun / Moon / ... or "ASC"/"MC"/"DSC"/"IC"
  final double lon;       // 0..360°
  final bool retro;
  final String? glyph;    // optional
  final Color? color;     // optional override
  final double? ring;     // if <=1 it's factor of radius; if >1 pixels
  final bool isTransit;

  const PlanetPos({
    required this.name,
    required this.lon,
    this.retro = false,
    this.glyph,
    this.color,
    this.ring,
    this.isTransit = false,
  });
}

class AspectHit {
  final String aName;
  final double aLon;
  final String bName;
  final double bLon;
  /// label יכול לכלול סימן/שם אספקט (☌,☍,□,△,✶ או Conjunction/Trine/…)
  final String label;
  final Color? color;    // אם null – יצבע לפי סוג האספקט
  final bool dashed;

  const AspectHit({
    required this.aName,
    required this.aLon,
    required this.bName,
    required this.bLon,
    required this.label,
    this.color,
    this.dashed = false,
  });
}

class ChartData {
  final double ascDeg;
  final double? mcDeg;
  final List<double>? houseCusps;

  // אם planets ריק – נשתמש ב-planetsNatal/planetsTransit
  final List<PlanetPos> planets;
  final List<PlanetPos> planetsNatal;
  final List<PlanetPos> planetsTransit;

  /// אספקטים לציור במרכז
  final List<AspectHit> aspects;

  final HouseSystem houseSystem;
  final bool zodiacGoesCCWFromAsc;          // נגד כיוון השעון מ-ASC
  final bool mirrorZodiacGlyphsVertically;  // לא בשימוש כרגע

  // שליטה גרפית
  final double aspectRadiusFactor;   // רדיוס טבעת האספקטים (יחסי לרדיוס)
  final double aspectStrokeFactor;   // עובי קווי אספקט (יחסי לרדיוס)
  final double zodiacInnerFactor;    // גבול פנימי של טבעת המזלות
  final double zodiacOuterFactor;    // גבול חיצוני של טבעת המזלות

  final double rotationCCWDeg;       // רוטציה כוללת (חיובי = נגד השעון)
  final bool showAscBadge;           // תווית ASC בקצה הקו

  const ChartData({
    required this.ascDeg,
    this.mcDeg,
    this.houseCusps,
    this.planets = const <PlanetPos>[],
    this.planetsNatal = const <PlanetPos>[],
    this.planetsTransit = const <PlanetPos>[],
    this.aspects = const <AspectHit>[],
    this.houseSystem = HouseSystem.equal,
    this.zodiacGoesCCWFromAsc = true,
    this.mirrorZodiacGlyphsVertically = true,
    this.aspectRadiusFactor = 0.34,
    this.aspectStrokeFactor = 0.005,
    this.zodiacInnerFactor = 0.80,
    this.zodiacOuterFactor = 0.88,
    this.rotationCCWDeg = 0.0,
    this.showAscBadge = false,
  });
}

/// =======================================================
/// Internal helpers (top-level)
/// =======================================================

class _Placed {
  final PlanetPos planet;
  final double angleRad;        // הזווית האמיתית (לא מזיזים מעלה!)
  double radialOffsetPx;        // הסטה רדיאלית פנימה/החוצה בפיקסלים
  _Placed(this.planet, this.angleRad, this.radialOffsetPx);
}

/// =======================================================
/// The Wheel Widget
/// =======================================================

class AstroWheel extends StatelessWidget {
  final ChartData data;
  final double size;
  final double fontScale;
  final Color background;

  /// טיקים פנימיים (בתוך טבעת המזלות)
  final bool showInnerDegreeTicks;

  final Map<String, ui.Image>? planetIcons;
  final double planetIconScale;
  final bool addAxesAsPlanets;
  final bool drawZodiacSeparators;

  /// גליפי מזלות מחוץ לטבעת
  final bool drawZodiacGlyphsAround;

  /// סולם מעלות חיצוני (כמו בתמונה)
  final bool showOuterDegreeScale;

  /// קנה־מידה ראשוני של הגלגל בתוך ה־Widget
  final double wheelScale;

  /// תנועות/זום עם אצבע (InteractiveViewer)
  final bool enablePanZoom;
  final double minScale;
  final double maxScale;

  final String glyphFontFamily;

  /// רדיוסי טבעות ברירת־מחדל
  final double natalRingFactor;
  final double transitRingFactor;

  /// לא בשימוש כאן (לא מזיזים זווית), נשמר להמשך אם תרצה
  final double minAngularSeparationDeg;

  /// מרחק מעלה להחשבת "אותה מעלה" (לצבירת קלאסטר רדיאלי)
  final double sameDegreeEpsilonDeg;

  /// כמה להזיז לכל שכבה (מוכפל בקוטר האייקון)
  final double sameDegreeStepFactor;

  const AstroWheel({
    super.key,
    required this.data,
    this.size = 420,
    this.fontScale = 1.0,
    this.background = Colors.white,
    this.showInnerDegreeTicks = true,
    this.planetIcons,
    this.planetIconScale = 0.11,
    this.addAxesAsPlanets = true,
    this.drawZodiacSeparators = true,
    this.drawZodiacGlyphsAround = true,
    this.showOuterDegreeScale = true,
    this.wheelScale = 0.92,
    this.enablePanZoom = true,
    this.minScale = 0.75,
    this.maxScale = 2.5,
    this.glyphFontFamily = 'NotoSansSymbols2',
    this.natalRingFactor = 0.78,
    this.transitRingFactor = 0.74,
    this.minAngularSeparationDeg = 7.0,
    this.sameDegreeEpsilonDeg = 8.0,    // הגדלנו את הטווח ל-3 מעלות כדי לתפוס יותר חפיפות פוטנציאליות
    this.sameDegreeStepFactor  = 1.0,    // נקטין מעט את הקפיצה הראשונית, הלוגיקה החדשה תתקן את המרחק במדויק
  });

  static Future<Map<String, ui.Image>> loadDefaultPlanetIcons() async {
    Future<ui.Image> _loadPng(String assetPath) async {
      final data = await rootBundle.load(assetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return frame.image;
    }

    const names = <String>[
      'sun','moon','mercury','venus','mars','jupiter','saturn','uranus','neptune','pluto',
      'chiron','node','south_node','asc','mc','dsc','ic',
    ];

    final out = <String, ui.Image>{};
    for (final n in names) {
      out[n] = await _loadPng('assets/planets/$n.png');
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final painter = _WheelPainter(
      data: data,
      fontScale: fontScale,
      background: background,
      showInnerDegreeTicks: showInnerDegreeTicks,
      planetIcons: planetIcons,
      planetIconScale: planetIconScale,
      addAxesAsPlanets: addAxesAsPlanets,
      drawZodiacSeparators: drawZodiacSeparators,
      drawZodiacGlyphsAround: drawZodiacGlyphsAround,
      showOuterDegreeScale: showOuterDegreeScale,
      wheelScale: wheelScale,
      glyphFontFamily: glyphFontFamily,
      natalRingFactor: natalRingFactor,
      transitRingFactor: transitRingFactor,
      minAngularSeparationDeg: minAngularSeparationDeg,
      sameDegreeEpsilonDeg: sameDegreeEpsilonDeg,
      sameDegreeStepFactor: sameDegreeStepFactor,
    );

    final child = RepaintBoundary(
      child: CustomPaint(size: Size.square(size), painter: painter),
    );

    if (!enablePanZoom) return child;

    return InteractiveViewer(
      minScale: minScale,
      maxScale: maxScale,
      boundaryMargin: const EdgeInsets.all(200),
      panEnabled: true,
      scaleEnabled: true,
      child: Center(child: child),
    );
  }
}

/// =======================================================
/// Internal Painter
/// =======================================================

class _WheelPainter extends CustomPainter {
  final ChartData data;
  final double fontScale;
  final Color background;
  final bool showInnerDegreeTicks;
  final Map<String, ui.Image>? planetIcons;
  final double planetIconScale;
  final bool addAxesAsPlanets;
  final bool drawZodiacSeparators;
  final bool drawZodiacGlyphsAround;
  final bool showOuterDegreeScale;
  final double wheelScale;
  final String glyphFontFamily;

  final double natalRingFactor;
  final double transitRingFactor;

  final double minAngularSeparationDeg; // לא מזיזים זווית כרגע
  final double sameDegreeEpsilonDeg;    // כן מזיזים רדיאלית כשיש אותה מעלה
  final double sameDegreeStepFactor;

  _WheelPainter({
    required this.data,
    required this.fontScale,
    required this.background,
    required this.showInnerDegreeTicks,
    required this.planetIcons,
    required this.planetIconScale,
    required this.addAxesAsPlanets,
    required this.drawZodiacSeparators,
    required this.drawZodiacGlyphsAround,
    required this.showOuterDegreeScale,
    required this.wheelScale,
    required this.glyphFontFamily,
    required this.natalRingFactor,
    required this.transitRingFactor,
    required this.minAngularSeparationDeg,
    required this.sameDegreeEpsilonDeg,
    required this.sameDegreeStepFactor,
  });

  double _deg2rad(double d) => d * math.pi / 180.0;
  double _norm360(double d) => (d % 360 + 360) % 360;
  double _arcCCW(double a, double b) => _norm360(b - a);

  double _signStart(double lon) => (_norm360(lon) ~/ 30) * 30.0;

  static const List<Color> _signColors = [
    Color(0xFFFFC1A1), // Aries
    Color(0xFFD1C4E9), // Taurus
    Color(0xFFB3E5FC), // Gemini
    Color(0xFFFFCDD2), // Cancer
    Color(0xFFFFE082), // Leo
    Color(0xFFC8E6C9), // Virgo
    Color(0xFFE1BEE7), // Libra
    Color(0xFFB39DDB), // Scorpio
    Color(0xFFFFAB91), // Sagittarius
    Color(0xFFB0BEC5), // Capricorn
    Color(0xFF81D4FA), // Aquarius
    Color(0xFF80CBC4), // Pisces
  ];

  final List<String> _zodiacGlyphs = const [
    '♈','♉','♊','♋','♌','♍','♎','♏','♐','♑','♒','♓',
  ];

  /// ASC בשעה 9 (שמאל). CCW אמיתי: angleDeg = -rel + 180
  double _theta(double lon) {
    final asc = _norm360(data.ascDeg);
    final rel = _norm360(lon - asc); // 0..360 ביחס ל-ASC
    double angleDeg = (data.zodiacGoesCCWFromAsc ? -rel : rel) + 180.0;
    angleDeg -= data.rotationCCWDeg;
    return _deg2rad(_norm360(angleDeg));
  }

  Offset _polar(Offset ctr, double r, double lon) {
    final a = _theta(lon);
    return Offset(ctr.dx + r * math.cos(a), ctr.dy + r * math.sin(a));
  }

  TextPainter _text(String s, double size, Color color,
      {FontWeight weight = FontWeight.w700, String? fontFamily}) {
    return TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: weight,
          height: 1.0,
          fontFamily: fontFamily,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
      maxLines: 2,
    );
  }

  // צבע אספקטים (כולל עברית) – צמידות בצבע Amber
  Color _aspectColor(String label) {
    final s = label.toLowerCase();
    if (s.contains('☍') || s.contains('opposition') || s.contains('אופוז')) {
      return const Color(0xFFE53935);
    }
    if (s.contains('□') || s.contains('square') || s.contains('ריבוע') || s.contains('סקוור')) {
      return const Color(0xFFFF7043);
    }
    if (s.contains('△') || s.contains('trine') || s.contains('טרין') || s.contains('משולש')) {
      return const Color(0xFF1E88E5);
    }
    if (s.contains('✶') || s.contains('sextile') || s.contains('סקסטיל') || s.contains('שיש')) {
      return const Color(0xFF26C6DA);
    }
    if (s.contains('☌') || s.contains('conjunction') || s.contains('צמיד')) {
      return Colors.amber; // <<< לא לגעת
    }
    return Colors.white70;
  }

  List<PlanetPos> _allPlanetsBase() {
    if (data.planets.isNotEmpty) return List<PlanetPos>.from(data.planets);

    final natal = data.planetsNatal.map((p) => PlanetPos(
      name: p.name, lon: p.lon, retro: p.retro, glyph: p.glyph,
      color: p.color ?? Colors.red, ring: p.ring, isTransit: false,
    ));

    final transit = data.planetsTransit.map((p) => PlanetPos(
      name: p.name, lon: p.lon, retro: p.retro, glyph: p.glyph,
      color: p.color ?? Colors.green, ring: p.ring, isTransit: true,
    ));

    final base = [...natal, ...transit];

    if (addAxesAsPlanets) {
      void addIfMissing(String name, double lon, Color col) {
        if (!base.any((p) => p.name.toLowerCase() == name.toLowerCase())) {
          base.add(PlanetPos(name: name, lon: _norm360(lon), color: col));
        }
      }
      final asc = _norm360(data.ascDeg);
      final dsc = _norm360(asc + 180.0);

      addIfMissing('ASC', asc, const Color(0xFFFF9800));
      addIfMissing('DSC', dsc, const Color(0xFFFF9800));

      if (data.mcDeg != null) {
        final mc = _norm360(data.mcDeg!);
        final ic = _norm360(mc + 180.0);
        addIfMissing('MC', mc, const Color(0xFF2196F3));
        addIfMissing('IC', ic, const Color(0xFF2196F3));
      }
    }

    // אם יש ראש דרקון ואין דרומי – נוסיף אוטומטית מולו
    final hasNode  = base.any((p) => p.name.toLowerCase() == 'node' || p.name == '☊');
    final hasSouth = base.any((p) => p.name.toLowerCase() == 'south node' || p.name == '☋');
    if (hasNode && !hasSouth) {
      final node = base.firstWhere((p) => p.name.toLowerCase() == 'node' || p.name == '☊');
      base.add(PlanetPos(
        name: 'South Node',
        lon: _norm360(node.lon + 180.0),
        color: node.color,
        isTransit: node.isTransit,
      ));
    }

    return base;
  }

  /// *** CCW ***: בית i = ASC + i*30°
  List<double> _equalCuspsFromAsc_clockwise(double ascDeg) {
    final asc = _norm360(ascDeg);
    return List<double>.generate(12, (i) => _norm360(asc + i * 30.0));
  }

  /// *** CCW ***: Whole Sign – תחילת המזל של ה-ASC + i*30°
  List<double> _wholeSignCuspsFromAsc_clockwise(double ascDeg) {
    final start = _signStart(ascDeg);
    return List<double>.generate(12, (i) => _norm360(start + i * 30.0));
  }

  List<double> _computeHouseCusps() {
    final asc = _norm360(data.ascDeg);

    if (data.houseSystem == HouseSystem.placidus &&
        data.houseCusps != null &&
        data.houseCusps!.length == 12) {
      final cusps = List<double>.from(data.houseCusps!.map(_norm360));
      // סדר CCW מה-ASC כך שהראשון = ASC
      cusps.sort((a, b) => _arcCCW(asc, a).compareTo(_arcCCW(asc, b)));
      cusps[0] = asc;
      return cusps;
    }

    if (data.houseSystem == HouseSystem.wholeSign) {
      return _wholeSignCuspsFromAsc_clockwise(asc);
    }
    return _equalCuspsFromAsc_clockwise(asc);
  }

  // ---- גורם ל־arcTo לצייר CCW (נגד השעון) ----
  double _ccwSweep(double start, double end) {
    double s = end - start;
    if (s > 0) s -= 2 * math.pi;
    return s;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final center = Offset(cx, cy);
    final radius = math.min(cx, cy) * wheelScale;

    // רקע
    canvas.drawCircle(center, radius, Paint()..color = background);

    // טבעת מזלות
    _drawZodiacBand(canvas, center, radius);

    // סולמות מעלות
    if (showOuterDegreeScale) _drawOuterDegreeScale(canvas, center, radius);
    if (showInnerDegreeTicks) _drawInnerDegreeTicks(canvas, center, radius);

    // גליפים סביב
    if (drawZodiacGlyphsAround) _drawZodiacGlyphs(canvas, center, radius);

    // בתים
    _drawHouses(canvas, center, radius);

    // צירים
    _drawAxes(canvas, center, radius);

    // אספקטים
    _drawAspectLines(canvas, center, radius);

    // כוכבים
    _drawPlanets(canvas, center, radius);
  }

  // ---------- Zodiac colored band ----------
  void _drawZodiacBand(Canvas c, Offset ctr, double radius) {
    final rInner = radius * data.zodiacInnerFactor;
    final rOuter = radius * data.zodiacOuterFactor;

    for (int k = 0; k < 12; k++) {
      final lon0 = k * 30.0;
      final lon1 = lon0 + 30.0;

      final start = _theta(lon0);
      final end   = _theta(lon1);
      final sweep = _ccwSweep(start, end);

      final path = Path()
        ..moveTo(ctr.dx + rInner * math.cos(start), ctr.dy + rInner * math.sin(start))
        ..arcTo(Rect.fromCircle(center: ctr, radius: rInner), start, sweep, false)
        ..arcTo(Rect.fromCircle(center: ctr, radius: rOuter), start + sweep, -sweep, false)
        ..close();

      c.drawPath(
        path,
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.fill
          ..color = _signColors[k].withOpacity(0.40),
      );

      if (drawZodiacSeparators) {
        final double outR   = rOuter + radius * 0.005;
        final double innerR = rInner - radius * 0.005;
        final paint30 = Paint()
          ..color = Colors.black
          ..strokeWidth = radius * 0.0030
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true;

        final p0a = Offset(ctr.dx + innerR * math.cos(start), ctr.dy + innerR * math.sin(start));
        final p0b = Offset(ctr.dx + outR   * math.cos(start), ctr.dy + outR   * math.sin(start));
        c.drawLine(p0a, p0b, paint30);

        final p1a = Offset(ctr.dx + innerR * math.cos(end), ctr.dy + innerR * math.sin(end));
        final p1b = Offset(ctr.dx + outR   * math.cos(end), ctr.dy + outR   * math.sin(end));
        c.drawLine(p1a, p1b, paint30);
      }
    }
  }

  // ---------- Outer degree scale ----------
  void _drawOuterDegreeScale(Canvas c, Offset ctr, double radius) {
    final double baseR  = radius * (data.zodiacOuterFactor + 0.015);
    final double longR  = baseR + radius * 0.070;  // 30°
    final double midR   = baseR + radius * 0.050;  // 10°
    final double smallR = baseR + radius * 0.030;  // 5°
    final double tinyR  = baseR + radius * 0.020;  // 1°

    final p1  = Paint()..color = Colors.black26..strokeWidth = radius * 0.0020..strokeCap = StrokeCap.round;
    final p5  = Paint()..color = Colors.black45..strokeWidth = radius * 0.0022..strokeCap = StrokeCap.round;
    final p10 = Paint()..color = Colors.black87..strokeWidth = radius * 0.0026..strokeCap = StrokeCap.round;
    final p30 = Paint()..color = Colors.black   ..strokeWidth = radius * 0.0032..strokeCap = StrokeCap.round;

    for (int deg = 0; deg < 360; deg++) {
      final a = _theta(deg.toDouble());
      final is30 = (deg % 30 == 0);
      final is10 = (deg % 10 == 0);
      final is5  = (deg % 5  == 0);

      double r2 = tinyR;
      Paint p = p1;
      if (is30)      { r2 = longR;  p = p30; }
      else if (is10) { r2 = midR;   p = p10; }
      else if (is5)  { r2 = smallR; p = p5;  }

      final pA = Offset(ctr.dx + baseR * math.cos(a), ctr.dy + baseR * math.sin(a));
      final pB = Offset(ctr.dx + r2    * math.cos(a), ctr.dy + r2    * math.sin(a));
      c.drawLine(pA, pB, p);
    }
  }

  // ---------- Inner degree ticks ----------
  void _drawInnerDegreeTicks(Canvas c, Offset ctr, double radius) {
    final double outer = radius * (data.zodiacInnerFactor - 0.02);
    final double inner = outer - radius * 0.10;

    final paint1  = Paint()..color = Colors.black26..strokeWidth = radius * 0.0020..strokeCap = StrokeCap.round;
    final paint5  = Paint()..color = Colors.black45..strokeWidth = radius * 0.0022..strokeCap = StrokeCap.round;
    final paint10 = Paint()..color = Colors.black87..strokeWidth = radius * 0.0025..strokeCap = StrokeCap.round;
    final paint30 = Paint()..color = Colors.black   ..strokeWidth = radius * 0.0030..strokeCap = StrokeCap.round;

    for (int deg = 0; deg < 360; deg++) {
      final a = _theta(deg.toDouble());
      final is30 = (deg % 30 == 0);
      final is10 = (deg % 10 == 0);
      final is5  = (deg % 5  == 0);

      double r1 = inner, r2 = outer;
      Paint p = paint1;

      if (is30)      { r1 = inner - radius * 0.015; p = paint30; }
      else if (is10) { r1 = inner - radius * 0.010; p = paint10; }
      else if (is5)  { r1 = inner - radius * 0.006; p = paint5;  }

      final pA = Offset(ctr.dx + r1 * math.cos(a), ctr.dy + r1 * math.sin(a));
      final pB = Offset(ctr.dx + r2 * math.cos(a), ctr.dy + r2 * math.sin(a));
      c.drawLine(pA, pB, p);
    }
  }

  // ---------- Zodiac glyphs ----------
  void _drawZodiacGlyphs(Canvas c, Offset ctr, double radius) {
    final rGlyph = radius * (data.zodiacOuterFactor + 0.035);

    for (int k = 0; k < 12; k++) {
      final centerLon = k * 30.0 + 15.0; // מרכז מזל אמיתי
      final glyph = _zodiacGlyphs[k];

      final pos = _polar(ctr, rGlyph, centerLon);
      final tp = _text(glyph, radius * 0.085 * fontScale, Colors.black87,
          weight: FontWeight.w800);
      tp.layout();
      tp.paint(c, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  // ---------- Houses ----------
  void _drawHouses(Canvas c, Offset ctr, double radius) {
    final rInner = radius * 0.60;
    final rOuter = radius * 0.74;

    final cusps = _computeHouseCusps();

    final line = Paint()
      ..color = Colors.black87
      ..strokeWidth = radius * 0.010
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    Color cusp1Color;
    switch (data.houseSystem) {
      case HouseSystem.equal:
        cusp1Color = const Color(0xFFFF9800);
        break;
      case HouseSystem.wholeSign:
        cusp1Color = const Color(0xFF9C27B0);
        break;
      case HouseSystem.placidus:
        cusp1Color = const Color(0xFF26A69A);
        break;
    }

    for (int i = 0; i < 12; i++) {
      final a = _theta(cusps[i]);
      final p1 = Offset(ctr.dx + rInner * math.cos(a), ctr.dy + rInner * math.sin(a));
      final p2 = Offset(ctr.dx + rOuter * math.cos(a), ctr.dy + rOuter * math.sin(a));

      if (i == 0) {
        c.drawLine(
          p1, p2,
          Paint()
            ..color = cusp1Color
            ..strokeWidth = radius * 0.015
            ..strokeCap = StrokeCap.round
            ..isAntiAlias = true,
        );
      } else {
        c.drawLine(p1, p2, line);
      }

      final next = (i + 1) % 12;
      final ccw = _arcCCW(cusps[i], cusps[next]);
      final mid = (ccw <= 180) ? _norm360(cusps[i] + ccw * 0.5)
                               : _norm360(cusps[i] - (360 - ccw) * 0.5);
      final pos = _polar(ctr, rInner - radius * 0.08, mid);

      final tp = _text('${i + 1}', radius * 0.07 * fontScale, Colors.black87);
      tp.layout();
      tp.paint(c, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  // ---------- Axes ----------
  void _drawAxes(Canvas c, Offset ctr, double radius) {
    final asc = _norm360(data.ascDeg);
    final dsc = _norm360(asc + 180.0);

    Offset axisTip(double lon) {
      final a = _theta(lon);
      return Offset(ctr.dx + radius * math.cos(a), ctr.dy + radius * math.sin(a));
    }

    void axis(double lon, String tag, Color col) {
      final p = axisTip(lon);
      c.drawLine(
        ctr, p,
        Paint()
          ..color = col
          ..strokeWidth = radius * 0.012
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true,
      );
      final tp = _text(tag, radius * 0.055 * fontScale, col);
      tp.layout();
      tp.paint(c, p - Offset(tp.width / 2, tp.height / 2));
    }

    axis(asc, 'ASC', const Color(0xFFFF9800));
    axis(dsc, 'DSC', const Color(0xFFFF9800));

    if (data.mcDeg != null) {
      final mc = _norm360(data.mcDeg!);
      final ic = _norm360(mc + 180.0);
      axis(mc , 'MC',  const Color(0xFF2196F3));
      axis(ic , 'IC',  const Color(0xFF2196F3));
    }
  }

  // ---------- Aspect lines ----------
  void _drawAspectLines(Canvas c, Offset ctr, double radius) {
    if (data.aspects.isEmpty) return;

    final double r = radius * data.aspectRadiusFactor;
    final double stroke = radius * data.aspectStrokeFactor;

    for (final a in data.aspects) {
      final double a1 = _theta(a.aLon);
      final double a2 = _theta(a.bLon);

      final Offset p1 = Offset(ctr.dx + r * math.cos(a1), ctr.dy + r * math.sin(a1));
      final Offset p2 = Offset(ctr.dx + r * math.cos(a2), ctr.dy + r * math.sin(a2));

      final paint = Paint()
        ..color = (a.color ?? _aspectColor(a.label))
        ..strokeWidth = stroke
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;

      if (a.dashed) {
        const dash = 6.0, gap = 4.0;
        final total = (p2 - p1).distance;
        final dir = (p2 - p1) / total;
        double t = 0;
        while (t < total) {
          final seg = math.min(dash, total - t);
          final s = p1 + dir * t;
          final e = p1 + dir * (t + seg);
          c.drawLine(s, e, paint);
          t += dash + gap;
        }
      } else {
        c.drawLine(p1, p2, paint);
      }
    }
  }

  // ---------- Planets ----------
void _drawPlanets(Canvas c, Offset ctr, double radius) {
  final Map<String, ui.Image> icons = planetIcons ?? const <String, ui.Image>{};

  final rNatalBase   = radius * natalRingFactor;
  final rTransitBase = radius * transitRingFactor;
  final iconDia      = radius * planetIconScale;

  // קודם נצייר את נקודות הצירים על ההיקף החיצוני
  final allPlanetsAndAxes = _allPlanetsBase();
  final axes = allPlanetsAndAxes.where((p) => _isAxis(p.name)).toList();
  for (final ax in axes) {
    final pos = _polar(ctr, radius * (data.zodiacOuterFactor + 0.03), ax.lon);
    _drawAxisDot(c, pos, ax, radius, iconDia);
  }

  // עכשיו נטפל בכוכבים בלבד (ללא הצירים)
  final allPlanets = allPlanetsAndAxes.where((p) => !_isAxis(p.name)).toList();
  
  // =========================================================================
  // *** התיקון המרכזי ***
  // שלב 1: חשב מיקומים עבור כל הכוכבים (לידה וטרנזיט) ביחד.
  // זה יאלץ את הלוגיקה למנוע התנגשות גם בין כוכב לידה לכוכב טרנזיט.
  final placedAll = _placeBySameDegree(allPlanets, iconDia, rNatalBase, rTransitBase);

  // שלב 2: עכשיו, צייר כל כוכב במיקום שחושב, על הטבעת המתאימה לו.
  for (final p in placedAll) {
    // קבע את הרדיוס והצבע לפי סוג הכוכב (לידה או טרנזיט)
    final baseRadius = p.planet.isTransit ? rTransitBase : rNatalBase;
    final color = p.planet.isTransit ? Colors.green : Colors.red;

    _drawPlanetIcon(
      c, ctr, icons, p.angleRad, baseRadius + p.radialOffsetPx, iconDia,
      color: color, // השתמש בצבע שקבענו
      retro: p.planet.retro,
      name: p.planet.name,
    );
  }
  // =========================================================================
}

  bool _isAxis(String n) {
    final t = n.toLowerCase();
    return t == 'asc' || t == 'mc' || t == 'dsc' || t == 'ic';
  }

  void _drawAxisDot(Canvas c, Offset pos, PlanetPos ax, double radius, double iconDia) {
    final col = ax.color ?? Colors.blueGrey;
    c.drawCircle(pos, iconDia * 0.22, Paint()..color = col..isAntiAlias = true);
  }

  // === גליף־פולבאק כשאין PNG ===
  String? _glyphForName(String name) {
    switch (name.trim().toLowerCase()) {
      case 'sun': return '☉';
      case 'moon': return '☽';
      case 'mercury': return '☿';
      case 'venus': return '♀';
      case 'mars': return '♂';
      case 'jupiter': return '♃';
      case 'saturn': return '♄';
      case 'uranus': return '♅';
      case 'neptune': return '♆';
      case 'pluto': return '♇';
      case 'earth': return '♁';
      case 'chiron': return '⚷';
      case 'node':
      case 'north node':
      case '☊': return '☊';
      case 'south node':
      case '☋': return '☋';
      case 'asc': return 'ASC';
      case 'mc':  return 'MC';
      case 'dsc': return 'DSC';
      case 'ic':  return 'IC';
    }
    return null;
  }

  // ---------- הלוגיקה: שכבות רדיאליות לפי "אותה מעלה" + אכיפת אי-חפיפה ----------
  List<_Placed> _placeBySameDegree(List<PlanetPos> planets, double iconDia, double rNatal, double rTransit) {
  if (planets.isEmpty) return const <_Placed>[];

  // הגדלנו מעט את הטווח כדי לתפוס את כל ההתנגשויות האפשריות
  final eps = sameDegreeEpsilonDeg.clamp(0.1, 5.0);
  final sorted = List<PlanetPos>.from(planets)..sort((a, b) => a.lon.compareTo(b.lon));
  
  final result = <_Placed>[];
  int i = 0;

  while (i < sorted.length) {
    int j = i + 1;
    while (j < sorted.length && _sameDegree(sorted[j - 1].lon, sorted[j].lon, eps)) {
      j++;
    }
    final cluster = sorted.sublist(i, j);

    // --- לוגיקת מיקום דטרמיניסטית חדשה ---
    if (cluster.isEmpty) {
      i = j;
      continue;
    }

    // 1. צור רשימת _Placed ראשונית עם היסט 0
    final placedCluster = cluster.map((p) => _Placed(p, _theta(p.lon), 0.0)).toList();

    // 2. מיין את הקבוצה לפי הרדיוס המקורי, מהחיצוני לפנימי
    placedCluster.sort((a, b) {
      final radiusA = a.planet.isTransit ? rTransit : rNatal;
      final radiusB = b.planet.isTransit ? rTransit : rNatal;
      return radiusB.compareTo(radiusA); // B.compareTo(A) for descending order
    });

    // 3. ערום את הכוכבים פנימה מהכוכב החיצוני ביותר
    if (placedCluster.length > 1) {
      // קבע את הרדיוס של הכוכב הראשון (החיצוני ביותר)
      double lastEffectiveRadius = (placedCluster[0].planet.isTransit ? rTransit : rNatal);

      for (int k = 1; k < placedCluster.length; k++) {
        final currentItem = placedCluster[k];
        final desiredOriginalRadius = currentItem.planet.isTransit ? rTransit : rNatal;

        // הרדיוס החדש חייב להיות קטן יותר מהקודם ברווח מינימלי
        // הרווח הוא קוטר אייקון + מרווח קטן נוסף (למשל 10% מהקוטר)
        final requiredGap = iconDia * 1.10;
        final newEffectiveRadius = lastEffectiveRadius - requiredGap;

        // ההיסט (offset) הוא ההפרש בין המיקום החדש למיקום הטבעת המקורי שלו
        currentItem.radialOffsetPx = newEffectiveRadius - desiredOriginalRadius;

        // עדכן את הרדיוס האחרון עבור האיטרציה הבאה
        lastEffectiveRadius = newEffectiveRadius;
      }
    }

    result.addAll(placedCluster);
    i = j;
  }

  return result;
}
    
  bool _sameDegree(double a, double b, double epsDeg) {
    final d = (_norm360(a) - _norm360(b)).abs();
    final dd = d > 180 ? 360 - d : d;
    return dd <= epsDeg; // באותה מעלה (בערך)
  }

  // ---------- ציור אייקון/גליף כוכב ----------
  void _drawPlanetIcon(
    Canvas c,
    Offset ctr,
    Map<String, ui.Image> icons,
    double angleRad,
    double ringPx,
    double iconDia, {
    required Color color,
    required bool retro,
    required String name,
  }) {
    final pos = Offset(ctr.dx + ringPx * math.cos(angleRad), ctr.dy + ringPx * math.sin(angleRad));
    final key = _normalizeKey(name);
    final ui.Image? icon = icons[key];

    if (icon != null) {
      // הילה לבנה מאחורי PNG כדי לא לבלע ברקע
      c.drawCircle(pos, iconDia * 0.58, Paint()..color = Colors.white.withOpacity(0.2)..isAntiAlias = true);
      final dst = Rect.fromCenter(center: pos, width: iconDia, height: iconDia);
      final src = Rect.fromLTWH(0, 0, icon.width.toDouble(), icon.height.toDouble());
      c.drawImageRect(icon, src, dst, Paint()..isAntiAlias = true);
    } else {
      final glyph = _glyphForName(name);
      if (glyph != null) {
        final isTextLabel = glyph.length > 1; // ASC/MC/DSC/IC
        if (!isTextLabel) {
          c.drawCircle(pos, iconDia * 0.58, Paint()..color = Colors.white.withOpacity(0.85)..isAntiAlias = true);
        }
        final tp = _text(
          glyph,
          iconDia * (isTextLabel ? 0.48 : 0.95),
          color,
          weight: FontWeight.w800,
          fontFamily: glyphFontFamily,
        );
        tp.layout();
        tp.paint(c, pos - Offset(tp.width / 2, tp.height / 2));
      } else {
        final r = iconDia * 0.40;
        c.drawCircle(pos, r, Paint()..color = color..isAntiAlias = true);
        c.drawCircle(
          pos,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.35
            ..color = Colors.white.withOpacity(0.85)
            ..isAntiAlias = true,
        );
      }
    }

    if (retro) {
      final tp = _text('R', iconDia * 0.45, Colors.black.withOpacity(0.85), // שינוי ל-R והקטנה קלה
          fontFamily: glyphFontFamily, weight: FontWeight.w800);
      tp.layout();
      tp.paint(c, pos + Offset(iconDia * 0.55, iconDia * 0.10));
    }
  }

  String _normalizeKey(String s) {
    final t = s.trim().toLowerCase();
    switch (t) {
      case 'sun': return 'sun';
      case 'moon': return 'moon';
      case 'mercury': return 'mercury';
      case 'venus': return 'venus';
      case 'mars': return 'mars';
      case 'jupiter': return 'jupiter';
      case 'saturn': return 'saturn';
      case 'uranus': return 'uranus';
      case 'neptune': return 'neptune';
      case 'pluto': return 'pluto';
      case 'chiron': return 'chiron';
      case 'node':
      case 'north node':
      case 'true node':
      case 'mean node':
      case 'ראשדרקון': return 'node';
      case 'south node':
      case 'זנבהדרקון': return 'south_node';
      case 'asc':
      case 'אופק':
      case 'אסצ':
      case 'אסצנדנט': return 'asc';
      case 'mc':
      case 'רוםהשמיים':
      case 'מרידיאן': return 'mc';
      case 'dsc': return 'dsc';
      case 'ic':  return 'ic';
      default: return t;
    }
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) =>
      old.data != data ||
      old.fontScale != fontScale ||
      old.background != background ||
      old.showInnerDegreeTicks != showInnerDegreeTicks ||
      old.planetIcons != planetIcons ||
      old.planetIconScale != planetIconScale ||
      old.addAxesAsPlanets != addAxesAsPlanets ||
      old.drawZodiacSeparators != drawZodiacSeparators ||
      old.drawZodiacGlyphsAround != drawZodiacGlyphsAround ||
      old.showOuterDegreeScale != showOuterDegreeScale ||
      old.wheelScale != wheelScale ||
      old.glyphFontFamily != glyphFontFamily ||
      old.natalRingFactor != natalRingFactor ||
      old.transitRingFactor != transitRingFactor ||
      old.minAngularSeparationDeg != minAngularSeparationDeg ||
      old.sameDegreeEpsilonDeg != sameDegreeEpsilonDeg ||
      old.sameDegreeStepFactor != sameDegreeStepFactor;
}
