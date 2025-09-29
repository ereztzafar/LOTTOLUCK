import 'dart:math' as math;
import 'package:flutter/material.dart';

/// =======================
/// מודלים בסיסיים
/// =======================
class PlanetPos {
  final String name;   // "Sun", "Moon", ...
  final double lon;    // 0..360°
  final bool retro;
  const PlanetPos({required this.name, required this.lon, this.retro = false});
}

class WheelSpec {
  final double ascDeg;            // ASC במעלות 0..360
  final double? mcDeg;            // אם null => ASC+90
  final double innerBand;         // טבעת פנימית (יחסי לרדיוס)
  final double outerBand;         // טבעת חיצונית (יחסי לרדיוס)
  const WheelSpec({
    required this.ascDeg,
    this.mcDeg,
    this.innerBand = 0.62,
    this.outerBand = 0.82,
  });
}

/// =======================
/// עזר/טריגו משותף
/// =======================
double _deg2rad(double d) => d * math.pi / 180.0;
double _norm360(double d) => (d % 360 + 360) % 360;

/// מיפוי מעלות -> זווית מסך כך שה-ASC בשעה 9 והתנועה CCW:
/// Δ = (lon - ASC)° , ואז θ = π - Δ
double _thetaCCW(double lon, double ascDeg) {
  final delta = _norm360(lon - _norm360(ascDeg)); // 0..360 יחסית ל-ASC
  return math.pi - _deg2rad(delta);
}

Offset _polar(Offset c, double r, double angleRad) =>
    Offset(c.dx + r * math.cos(angleRad), c.dy + r * math.sin(angleRad));

int _signIndex(double lon) => (_norm360(lon) ~/ 30) % 12;
double _signStart(double lon) => (_norm360(lon) ~/ 30) * 30.0;

/// =======================
/// 1) בסיס הגלגל: 2 עיגולים + 360° + 12
/// =======================
class WheelBase360Painter extends CustomPainter {
  final WheelSpec spec;
  final Color background;
  final Color ringColor;
  final Color tickColor;
  final Color sectorColor;

  const WheelBase360Painter({
    required this.spec,
    this.background = Colors.white,
    this.ringColor = const Color(0xFFDDDDDD),
    this.tickColor = const Color(0xFF8C8C8C),
    this.sectorColor = Colors.black,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final ctr = Offset(cx, cy);
    final R = math.min(cx, cy) * 0.95;

    // רקע
    canvas.drawCircle(ctr, R, Paint()..color = background);

    // שתי טבעות
    final rInner = R * spec.innerBand;
    final rOuter = R * spec.outerBand;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = R * 0.010
      ..color = ringColor;
    canvas.drawCircle(ctr, rInner, ring);
    canvas.drawCircle(ctr, rOuter, ring);

    // טיקים 360°
    final base = rOuter + R * 0.010;
    for (int d = 0; d < 360; d++) {
      final a = _thetaCCW(d.toDouble(), spec.ascDeg);
      final is30 = d % 30 == 0, is10 = d % 10 == 0, is5 = d % 5 == 0;

      double len;
      if (is30)      len = R * 0.080;
      else if (is10) len = R * 0.055;
      else if (is5)  len = R * 0.035;
      else           len = R * 0.020;

      canvas.drawLine(
        _polar(ctr, base, a),
        _polar(ctr, base + len, a),
        Paint()
          ..color = tickColor.withOpacity(is30 ? 1.0 : is10 ? 0.9 : is5 ? 0.75 : 0.5)
          ..strokeWidth = is30 ? R * 0.0032 : is10 ? R * 0.0026 : R * 0.0020,
      );
    }

    // 12 קווים רדיאליים (בתים) – בית 1 מתחיל בדיוק ב-ASC
    for (int k = 0; k < 12; k++) {
      final lon = spec.ascDeg + k * 30.0;         // CCW
      final a = _thetaCCW(lon, spec.ascDeg);
      canvas.drawLine(
        _polar(ctr, 0, a),
        _polar(ctr, R, a),
        Paint()..color = sectorColor..strokeWidth = R * 0.0045,
      );
    }

    // קו ASC מודגש
    final aAsc = _thetaCCW(spec.ascDeg, spec.ascDeg);
    canvas.drawLine(
      _polar(ctr, 0, aAsc),
      _polar(ctr, R, aAsc),
      Paint()..color = const Color(0xFFFF9800)..strokeWidth = R * 0.010,
    );
  }

  @override
  bool shouldRepaint(covariant WheelBase360Painter old) =>
      old.spec != spec ||
      old.background != background ||
      old.ringColor != ringColor ||
      old.tickColor != tickColor ||
      old.sectorColor != sectorColor;
}

/// ===============================================
/// 2) מזלות מסביב + קווי ASC/MC (אופציונלי DSC/IC)
/// ===============================================
class SignsAxesPainter extends CustomPainter {
  final WheelSpec spec;
  final bool showDSCIC;
  final TextStyle signStyle;

  const SignsAxesPainter({
    required this.spec,
    this.showDSCIC = false,
    this.signStyle = const TextStyle(
      fontSize: 14,
      color: Colors.black87,
      fontWeight: FontWeight.w800,
    ),
  });

  static const glyphs = ['♈','♉','♊','♋','♌','♍','♎','♏','♐','♑','♒','♓'];

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final ctr = Offset(cx, cy);
    final R = math.min(cx, cy) * 0.95;

    final rOuter = R * spec.outerBand;
    final rText  = rOuter + R * 0.045;

    // מזלות – מתחילים מהמזל של ה-ASC ומתקדמים CCW
    final startIdx = _signIndex(spec.ascDeg);
    final startLon = _signStart(spec.ascDeg);
    for (int i = 0; i < 12; i++) {
      final gi = (startIdx + i) % 12;
      final lonMid = startLon + i * 30.0 + 15.0;
      final a = _thetaCCW(lonMid, spec.ascDeg);

      final tp = TextPainter(
        text: TextSpan(text: glyphs[gi], style: signStyle.copyWith(fontSize: R * 0.085)),
        textDirection: TextDirection.ltr,
      )..layout();
      final pos = _polar(ctr, rText, a);
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }

    // קווי ASC/MC (+ אופציונלי DSC/IC)
    void axis(double lon, String tag, Color col) {
      final a = _thetaCCW(lon, spec.ascDeg);
      final p = _polar(ctr, R, a);
      canvas.drawLine(ctr, p, Paint()..color = col..strokeWidth = R * 0.012);
      final tp = TextPainter(
        text: TextSpan(text: tag, style: TextStyle(color: col, fontSize: R * 0.055, fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }

    final asc = _norm360(spec.ascDeg);
    final mc  = _norm360(spec.mcDeg ?? asc + 90.0); // ברירת־מחדל: MC למעלה

    axis(asc, 'ASC', const Color(0xFFFF9800));
    axis(mc , 'MC',  const Color(0xFF2196F3));
    if (showDSCIC) {
      axis(_norm360(asc + 180.0), 'DSC', const Color(0xFFFF9800));
      axis(_norm360(mc  + 180.0), 'IC',  const Color(0xFF2196F3));
    }
  }

  @override
  bool shouldRepaint(covariant SignsAxesPainter old) =>
      old.spec != spec || old.showDSCIC != showDSCIC || old.signStyle != signStyle;
}

/// ========================================
/// 3) כוכבים – לידה (אדום) וטרנזיט (ירוק)
/// ========================================
class PlanetsPainter extends CustomPainter {
  final WheelSpec spec;
  final List<PlanetPos> natal;     // אדום
  final List<PlanetPos> transits;  // ירוק
  final double ringNatalFactor;    // רדיוס נקודות לידה (יחסי לרדיוס)
  final double ringTransitFactor;  // רדיוס נקודות טרנזיט
  final double dotSizeFactor;      // קוטר יחסי של הנקודה

  const PlanetsPainter({
    required this.spec,
    required this.natal,
    required this.transits,
    this.ringNatalFactor = 0.70,
    this.ringTransitFactor = 0.74,
    this.dotSizeFactor = 0.075,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final ctr = Offset(cx, cy);
    final R = math.min(cx, cy) * 0.95;

    final rN = R * ringNatalFactor;
    final rT = R * ringTransitFactor;
    final dia = R * dotSizeFactor;

    void dot(PlanetPos p, Color col, double rr) {
      final a = _thetaCCW(p.lon, spec.ascDeg);
      final pos = _polar(ctr, rr, a);
      canvas.drawCircle(pos, dia * 0.45, Paint()..color = col..isAntiAlias = true);

      if (p.retro) {
        final tp = TextPainter(
          text: TextSpan(text: '℞', style: TextStyle(fontSize: dia * 0.55, color: Colors.black, fontWeight: FontWeight.w800)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, pos + Offset(dia * 0.50, dia * 0.10));
      }
    }

    for (final p in natal)   { dot(p, const Color(0xFFD32F2F), rN); }
    for (final p in transits){ dot(p, const Color(0xFF2E7D32), rT); }
  }

  @override
  bool shouldRepaint(covariant PlanetsPainter old) =>
      old.spec != spec ||
      old.natal != natal ||
      old.transits != transits ||
      old.ringNatalFactor != ringNatalFactor ||
      old.ringTransitFactor != ringTransitFactor ||
      old.dotSizeFactor != dotSizeFactor;
}

/// ========================================
/// 4) אספקטים בין לידה ↔︎ טרנזיט
///    90° = אדום, 60° = ירוק, 120° = כחול
/// ========================================
class AspectsPainter extends CustomPainter {
  final WheelSpec spec;
  final List<PlanetPos> natal;
  final List<PlanetPos> transits;
  final double orbDeg;         // אורב (טולרנס) במעלות
  final double radiusFactor;   // רדיוס טבעת האספקטים

  const AspectsPainter({
    required this.spec,
    required this.natal,
    required this.transits,
    this.orbDeg = 2.0,
    this.radiusFactor = 0.38,
  });

  double _minAngle(double a) {
    final x = _norm360(a);
    return x > 180 ? 360 - x : x;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final ctr = Offset(cx, cy);
    final R = math.min(cx, cy) * 0.95;
    final r = R * radiusFactor;

    const c90  = Color(0xFFD32F2F); // אדום חזק
    const c60  = Color(0xFF2E7D32); // ירוק חזק
    const c120 = Color(0xFF1565C0); // כחול חזק

    Offset pt(double lon) => _polar(ctr, r, _thetaCCW(lon, spec.ascDeg));

    for (final n in natal) {
      for (final t in transits) {
        final diff = _minAngle(t.lon - n.lon);
        Color? col;
        if ((diff - 90).abs()  <= orbDeg)  col = c90;
        else if ((diff - 60).abs()  <= orbDeg)  col = c60;
        else if ((diff - 120).abs() <= orbDeg) col = c120;

        if (col != null) {
          canvas.drawLine(
            pt(n.lon), pt(t.lon),
            Paint()..color = col..strokeWidth = R * 0.006..isAntiAlias = true,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant AspectsPainter old) =>
      old.spec != spec ||
      old.natal != natal ||
      old.transits != transits ||
      old.orbDeg != orbDeg ||
      old.radiusFactor != radiusFactor;
}

/// ========================================
/// קומפוזיט: Stack של ארבע השכבות
/// ========================================
class AstroWheelLayered extends StatelessWidget {
  final WheelSpec spec;
  final List<PlanetPos> natal;
  final List<PlanetPos> transits;
  final double size;
  final bool showDSCIC;

  const AstroWheelLayered({
    super.key,
    required this.spec,
    required this.natal,
    required this.transits,
    this.size = 380,
    this.showDSCIC = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: WheelBase360Painter(spec: spec)),
          CustomPaint(painter: SignsAxesPainter(spec: spec, showDSCIC: showDSCIC)),
          CustomPaint(painter: PlanetsPainter(spec: spec, natal: natal, transits: transits)),
          CustomPaint(painter: AspectsPainter(spec: spec, natal: natal, transits: transits)),
        ],
      ),
    );
  }
}
