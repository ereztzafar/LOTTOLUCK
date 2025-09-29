import 'dart:math' as math;

/// שירות חישוב ASC/MC ללא תלות באינטרנט.
/// קלט: זמן ב-UTC (DateTime.utc), קו רוחב/אורך במעלות (צפון/מזרח חיובי).
/// פלט: מעלות אקליפטיות 0..360 לכל אחת מהנקודות.
class AscMc {
  final double ascDeg;
  final double mcDeg;

  const AscMc(this.ascDeg, this.mcDeg);

  static AscMc compute({
    required DateTime utc,     // חשוב: UTC, לא זמן מקומי
    required double latitude,  // +צפון/-דרום
    required double longitude, // +מזרח/-מערב
  }) {
    final jd = _julianDay(utc);
    final T = (jd - 2451545.0) / 36525.0;
    final eps = _deg2rad(_obliquityDeg(T));
    // ✨ נרמול נכון (לא % שיכול להחזיר שלילי):
    final lstDeg = _normDeg(_gmstDeg(jd) + longitude); // LST = GMST + λ
    final theta = _deg2rad(lstDeg);
    final phi   = _deg2rad(latitude);

    // ---- MC (סגור-צורה, מדויק)
    final lambdaMc = math.atan2(math.sin(theta), math.cos(theta) * math.cos(eps));
    final mc = _normDeg(_rad2deg(lambdaMc));

    // ---- ASC (איתור נומרי יציב)
    final asc = _ascendantNumerical(theta: theta, phi: phi, eps: eps);

    return AscMc(asc, mc);
  }

  // ========= Math/astro helpers =========
  static double _deg2rad(double d) => d * math.pi / 180.0;
  static double _rad2deg(double r) => r * 180.0 / math.pi;
  static double _normDeg(double d) => (d % 360 + 360) % 360;

  /// Julian Day (UT) – Meeus
  static double _julianDay(DateTime utc) {
    assert(utc.isUtc, 'utc must be in UTC');
    int Y = utc.year, M = utc.month;
    if (M <= 2) { Y -= 1; M += 12; }
    final A = (Y / 100).floor();
    final B = 2 - A + (A / 4).floor();
    final dayFrac = (utc.hour + (utc.minute + utc.second / 60.0) / 60.0) / 24.0;
    final D = utc.day + dayFrac;
    final JD = (365.25 * (Y + 4716)).floor()
             + (30.6001 * (M + 1)).floor()
             + D + B - 1524.5;
    return JD;
  }

  /// GMST (deg)
  static double _gmstDeg(double jd) {
    final T = (jd - 2451545.0) / 36525.0;
    double theta = 280.46061837
                 + 360.98564736629 * (jd - 2451545.0)
                 + 0.000387933 * T * T
                 - T * T * T / 38710000.0;
    return _normDeg(theta);
  }

  /// נטיית המילקה (deg)
  static double _obliquityDeg(double T) {
    // ε = 23° 26′ 21.448″ − 46.8150″T − 0.00059″T² + 0.001813″T³
    final eps0 = 23.0 + 26.0/60.0 + 21.448/3600.0;
    return eps0
         - (46.8150/3600.0) * T
         - (0.00059/3600.0) * T * T
         + (0.001813/3600.0) * T * T * T;
  }

  /// RA/Dec עבור אקליפטיקה λ (β=0)
  static (double alpha, double delta) _raDecFromLambda(double lambdaRad, double epsRad) {
    final sinLam = math.sin(lambdaRad), cosLam = math.cos(lambdaRad);
    final cosE   = math.cos(epsRad),   sinE   = math.sin(epsRad);
    final alpha  = math.atan2(sinLam * cosE,  cosLam);
    final delta  = math.asin(sinLam * sinE);
    return (alpha, delta);
  }

  /// גובה/אזימוט (רדיאנים) מ-RA/Dec, נתון LST=theta, lat=phi.
  static (double h, double A) _altAzFromRaDec({
    required double alpha, required double delta,
    required double theta, required double phi,
  }) {
    var H = theta - alpha;                       // hour angle
    H = (H + math.pi) % (2 * math.pi) - math.pi; // −π..π

    final sinH = math.sin(H),   cosH = math.cos(H);
    final sinPhi = math.sin(phi), cosPhi = math.cos(phi);
    final sinDelta = math.sin(delta), cosDelta = math.cos(delta);

    final sin_h = sinPhi * sinDelta + cosPhi * cosDelta * cosH;
    final h = math.asin(sin_h);

    final cos_h = math.cos(h);
    final sinA = -sinH * cosDelta / cos_h;
    final cosA = (sinDelta - math.sin(h) * sinPhi) / (cos_h * cosPhi);
    final A = math.atan2(sinA, cosA); // 0..2π אחרי נירמול חיצוני

    return (h, A);
  }

  /// מוצא את האסקנדנט כ-λ על האקליפטיקה שבו h≈0° והאזימוט במזרח (0°..180°).
  static double _ascendantNumerical({
    required double theta, required double phi, required double eps,
  }) {
    double bestLam = 0, bestErr = 1e9;

    double altDegAt(double lamDeg) {
      final lam = _deg2rad(lamDeg);
      final (alpha, delta) = _raDecFromLambda(lam, eps);
      final (h, _) = _altAzFromRaDec(alpha: alpha, delta: delta, theta: theta, phi: phi);
      return _rad2deg(h);
    }

    bool isEast(double lamDeg) {
      final lam = _deg2rad(lamDeg);
      final (alpha, delta) = _raDecFromLambda(lam, eps);
      final (_, A) = _altAzFromRaDec(alpha: alpha, delta: delta, theta: theta, phi: phi);
      final Adeg = _normDeg(_rad2deg(A));
      return Adeg > 0 && Adeg < 180; // מזרח
    }

    // חיפוש גס כל 0.5°
    for (double lam = 0; lam < 360; lam += 0.5) {
      if (!isEast(lam)) continue;
      final err = altDegAt(lam).abs();
      if (err < bestErr) { bestErr = err; bestLam = lam; }
    }

    // ליטוש סביב המועמד הטוב – Golden Section
    double a = bestLam - 1.0, b = bestLam + 1.0;
    const gr = 1.618033988749895;
    for (int i = 0; i < 60; i++) {
      final c = b - (b - a) / gr;
      final d = a + (b - a) / gr;
      final fc = altDegAt(c).abs();
      final fd = altDegAt(d).abs();
      if (fc < fd) { b = d; } else { a = c; }
    }
    double asc = (a + b) / 2.0;
    if (!isEast(asc)) asc = _normDeg(asc + 180); // ביטחון

    return _normDeg(asc);
  }
}
