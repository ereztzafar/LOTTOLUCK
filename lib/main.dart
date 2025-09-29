import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import 'models/city.dart';
import 'package:lottoluck/widgets/city_search_widget.dart';
import 'screens/pro_screen.dart';
import 'services/ads_service.dart';
import 'services/purchase_service.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

import 'services/asc_mc.dart';
import 'widgets/astro_wheel.dart';

/// ===== פונקציות גלובליות לשיטת בתים =====
String houseSystemApiValue(HouseSystem hs) {
  switch (hs) {
    case HouseSystem.equal:
      return 'equal';
    case HouseSystem.wholeSign:
      return 'whole_sign';
    case HouseSystem.placidus:
      return 'placidus';
  }
}

/// תווית ידידותית לשיטת בתים - בלי תלות במפתחות l10n שאולי חסרים
String houseSystemLabel(BuildContext context, HouseSystem hs) {
  final lang = Localizations.localeOf(context).languageCode.toLowerCase();

  String t(String en, String he, String ar, String ru, String fr, String es, String pt) {
    switch (lang) {
      case 'he':
        return he;
      case 'ar':
        return ar;
      case 'ru':
        return ru;
      case 'fr':
        return fr;
      case 'es':
        return es;
      case 'pt':
        return pt;
      default:
        return en;
    }
  }

  switch (hs) {
    case HouseSystem.equal:
      return t(
        'Equal Houses',
        'בתים שווים',
        'منازل متساوية',
        'Равные дома',
        'Maisons égales',
        'Casas iguales',
        'Casas iguais',
      );
    case HouseSystem.wholeSign:
      return t(
        'Whole Sign',
        'וֹהוֹל־סיין (מזל שלם)',
        'البرج الكامل',
        'Целый знак',
        'Signe entier',
        'Signo completo',
        'Signo inteiro',
      );
    case HouseSystem.placidus:
      return t(
        'Placidus',
        'פלסידוס',
        'بلَسيدوس',
        'Плацидус',
        'Placidus',
        'Plácido',
        'Placidus',
      );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();

  await PurchaseService.instance.init();
  if (Platform.isAndroid || Platform.isIOS) {
    await AdsService.init();
  }
  runApp(const LottoLuckApp());
}

class LottoLuckApp extends StatelessWidget {
  const LottoLuckApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark();
    final theme = base.copyWith(
      scaffoldBackgroundColor: Colors.black,
      colorScheme: base.colorScheme.copyWith(
        primary: Colors.deepPurple,
        secondary: Colors.amber,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amber,
          foregroundColor: Colors.black,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: const TextStyle(color: Colors.white70),
      ),
    );

    return MaterialApp(
      title: 'LOTTOLUCK',
      theme: theme,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        AppLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('he'),
        Locale('en'),
        Locale('ar'),
        Locale('ru'),
        Locale('fr'),
        Locale('es'),
        Locale('pt'),
      ],
      home: const RegistrationScreen(),
    );
  }
}

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});
  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController dateTextCtrl = TextEditingController();
  final TextEditingController timeTextCtrl = TextEditingController();

  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  City? selectedCity;

  String _tzId = 'Asia/Jerusalem';
  HouseSystem _houseSystem = HouseSystem.placidus;

  static const List<String> _ianaChoices = <String>[
    'UTC',
    'Africa/Cairo',
    'Africa/Johannesburg',
    'America/Chicago',
    'America/Denver',
    'America/Los_Angeles',
    'America/New_York',
    'America/Sao_Paulo',
    'Asia/Dubai',
    'Asia/Hong_Kong',
    'Asia/Jerusalem',
    'Asia/Kolkata',
    'Asia/Singapore',
    'Asia/Tokyo',
    'Australia/Sydney',
    'Europe/Amsterdam',
    'Europe/Berlin',
    'Europe/Lisbon',
    'Europe/London',
    'Europe/Madrid',
    'Europe/Moscow',
    'Europe/Paris',
    'Europe/Rome',
  ];

  final FocusNode nameFocus = FocusNode();
  final FocusNode dateFocusNode = FocusNode();
  final FocusNode timeFocusNode = FocusNode();

  bool get isFormComplete =>
      nameController.text.trim().isNotEmpty &&
      selectedCity != null &&
      selectedDate != null &&
      selectedTime != null &&
      _tzId.isNotEmpty;

  @override
  void dispose() {
    nameController.dispose();
    dateTextCtrl.dispose();
    timeTextCtrl.dispose();
    nameFocus.dispose();
    dateFocusNode.dispose();
    timeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18),
      firstDate: DateTime(1900),
      lastDate: now,
      locale: Localizations.localeOf(context),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
        dateTextCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 6, minute: 0),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked != null) {
      setState(() {
        selectedTime = picked;
        timeTextCtrl.text =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  void _autoPickTzForCity(City city) {
    final country = (city.country ?? '').toLowerCase();
    String guess = _tzId;

    if (country.contains('israel') ||
        country.contains('il') ||
        country.contains('ישראל')) {
      guess = 'Asia/Jerusalem';
    } else if (country.contains('united states') ||
        country.contains('usa') ||
        country.contains('us')) {
      guess = 'America/New_York';
    } else if (country.contains('united kingdom') ||
        country.contains('uk') ||
        country.contains('england')) {
      guess = 'Europe/London';
    } else if (country.contains('france')) {
      guess = 'Europe/Paris';
    } else if (country.contains('germany')) {
      guess = 'Europe/Berlin';
    } else if (country.contains('spain')) {
      guess = 'Europe/Madrid';
    } else if (country.contains('portugal')) {
      guess = 'Europe/Lisbon';
    } else if (country.contains('brazil')) {
      guess = 'America/Sao_Paulo';
    } else if (country.contains('russia')) {
      guess = 'Europe/Moscow';
    } else if (country.contains('india')) {
      guess = 'Asia/Kolkata';
    } else if (country.contains('japan')) {
      guess = 'Asia/Tokyo';
    } else if (country.contains('australia')) {
      guess = 'Australia/Sydney';
    } else if (country.contains('south africa')) {
      guess = 'Africa/Johannesburg';
    } else if (country.contains('uae') ||
        country.contains('united arab emirates') ||
        country.contains('dubai')) {
      guess = 'Asia/Dubai';
    }

    setState(() => _tzId = guess);
  }

  Future<Map<String, dynamic>> _runForecast() async {
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate!);
    final timeStr =
        '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}';
    final houseSystemParam = houseSystemApiValue(_houseSystem);
    final lang = Localizations.localeOf(context).languageCode;

    if (Platform.isAndroid || Platform.isIOS) {
      final host = Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';
      final uri = Uri.parse('http://$host:8000/forecast');
      final payload = {
        'date': dateStr,
        'time': timeStr,
        'city': selectedCity!.name,
        'lat': selectedCity!.latitude.toString(),
        'lon': selectedCity!.longitude.toString(),
        'lang': lang,
        'tz': _tzId,
        'house_system': houseSystemParam,
      };

      final resp = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 60));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      } else {
        throw Exception(
            'HTTP ${resp.statusCode} from $uri\n${utf8.decode(resp.bodyBytes)}');
      }
    }

    final result = await Process.run(
      'python',
      [
        'python/astrology_forecast.py',
        dateStr,
        timeStr,
        selectedCity!.name,
        selectedCity!.latitude.toString(),
        selectedCity!.longitude.toString(),
        lang,
        _tzId,
        houseSystemParam,
      ],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
      environment: const {'PYTHONIOENCODING': 'utf-8'},
      runInShell: true,
    );

    if (result.exitCode == 0) {
      return jsonDecode(result.stdout) as Map<String, dynamic>;
    } else {
      throw Exception(result.stderr);
    }
  }

  Future<void> _submit() async {
    if (!isFormComplete) return;

    FocusScope.of(context).unfocus();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final data = await _runForecast();
      if (!mounted) return;
      Navigator.of(context).pop();

      final birthDateStr = DateFormat('yyyy-MM-dd').format(selectedDate!);
      final birthTimeStr =
          '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}';

      if (Platform.isAndroid || Platform.isIOS) {
        await AdsService.showInterstitialIfNeeded(isPro: false);
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ForecastScreen(
            forecastData: data,
            birthDate: birthDateStr,
            birthTime: birthTimeStr,
            tz: _tzId,
            lat: selectedCity!.latitude.toString(),
            lon: selectedCity!.longitude.toString(),
            houseSystem: _houseSystem,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      final l = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.error_running_forecast(e.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.register_title),
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
            colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white10),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 18,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      l.tagline_connect_luck,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Name
                    TextField(
                      controller: nameController,
                      focusNode: nameFocus,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l.first_name_label,
                        prefixIcon: const Icon(Icons.person_outline, color: Colors.white70),
                      ),
                      style: const TextStyle(color: Colors.white),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) =>
                          FocusScope.of(context).requestFocus(dateFocusNode),
                    ),
                    const SizedBox(height: 16),

                    // City
                    CitySearchWidget(
                      onCitySelected: (City city) {
                        setState(() {
                          selectedCity = city;
                          _autoPickTzForCity(city);
                        });
                      },
                    ),
                    if (selectedCity != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 18, color: Colors.amber),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              l.city_selected_template(
                                selectedCity!.name,
                                selectedCity!.country ?? '',
                                selectedCity!.latitude.toStringAsFixed(3),
                                selectedCity!.longitude.toStringAsFixed(3),
                              ),
                              style: const TextStyle(color: Colors.white70),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Date
                    TextFormField(
                      controller: dateTextCtrl,
                      focusNode: dateFocusNode,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: l.birth_date_label,
                        prefixIcon:
                            const Icon(Icons.calendar_today, color: Colors.white70),
                      ),
                      textInputAction: TextInputAction.next,
                      onTap: () async {
                        await _pickDate();
                        if (selectedDate != null) {
                          FocusScope.of(context).requestFocus(timeFocusNode);
                        }
                      },
                    ),
                    const SizedBox(height: 10),

                    // Time
                    TextFormField(
                      controller: timeTextCtrl,
                      focusNode: timeFocusNode,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: l.birth_time_label,
                        prefixIcon:
                            const Icon(Icons.access_time, color: Colors.white70),
                      ),
                      textInputAction: TextInputAction.done,
                      onTap: () async => _pickTime(),
                    ),

                    const SizedBox(height: 12),

                    // Time Zone (IANA) picker
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: l.time_zone_label,
                        prefixIcon: const Icon(Icons.public, color: Colors.white70),
                        border: const OutlineInputBorder(),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _tzId,
                          isExpanded: true,
                          items: _ianaChoices
                              .map((z) => DropdownMenuItem(
                                    value: z,
                                    child: Text(z, overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _tzId = v ?? _tzId),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // House System picker
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: l.house_system_label,
                        prefixIcon:
                            const Icon(Icons.house_outlined, color: Colors.white70),
                        border: const OutlineInputBorder(),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<HouseSystem>(
                          value: _houseSystem,
                          isExpanded: true,
                          items: HouseSystem.values
                              .map((hs) => DropdownMenuItem(
                                    value: hs,
                                    child: Text(houseSystemLabel(context, hs)),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _houseSystem = v ?? _houseSystem),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isFormComplete ? _submit : null,
                        icon: const Icon(Icons.star_border),
                        label: Text(l.show_forecast_button),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (!isFormComplete)
                      Text(
                        l.form_incomplete_hint,
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ================= אספקטים על הגלגל =================

class _AspectSegment {
  final double fromDeg; // טרנזיט (מקור)
  final double toDeg; // נאטלי (יעד)
  final String label; // לא בשימוש בציור (לשימוש עתידי)
  final Color color;

  _AspectSegment({
    required this.fromDeg,
    required this.toDeg,
    required this.label,
    required this.color,
  });
}

Color _aspectColor(String aspectName) {
  final a = aspectName.toLowerCase();
  if (a.contains('square') || a.contains('ריבוע')) return Colors.redAccent;
  if (a.contains('trine') || a.contains('משולש')) return Colors.blueAccent;
  if (a.contains('opposition') || a.contains('אופוזיציה')) return Colors.orangeAccent;
  if (a.contains('sextile') || a.contains('שישית')) return Colors.tealAccent;
  if (a.contains('conjunction') || a.contains('צמידות')) return Colors.amberAccent;
  return Colors.white70;
}

double _toRad(double deg) => deg * math.pi / 180.0;
double _norm360(double deg) {
  var x = deg % 360.0;
  if (x < 0) x += 360.0;
  return x;
}

String _planetGlyph(String name) {
  switch (name) {
    case 'Sun':
      return '☉';
    case 'Moon':
      return '☾';
    case 'Mercury':
      return '☿';
    case 'Venus':
      return '♀';
    case 'Mars':
      return '♂';
    case 'Jupiter':
      return '♃';
    case 'Saturn':
      return '♄';
    case 'Uranus':
      return '♅';
    case 'Neptune':
      return '♆';
    case 'Pluto':
      return '♇';
    case 'Node':
    case 'North Node':
    case 'True Node':
    case 'Mean Node':
      return '☊';
    case 'South Node':
      return '☋';
    case 'ASC':
      return 'ASC';
    case 'MC':
      return 'MC';
    default:
      return name;
  }
}

String _aspectSymbol(String asp) {
  final a = asp.toLowerCase();
  if (a.contains('conjunction') || a.contains('צמידות')) return '☌';
  if (a.contains('opposition') || a.contains('אופוזיציה')) return '☍';
  if (a.contains('square') || a.contains('ריבוע')) return '□';
  if (a.contains('trine') || a.contains('משולש')) return '△';
  if (a.contains('sextile') || a.contains('שישית')) return '✶';
  return asp;
}

class _AspectsOnWheelPainter extends CustomPainter {
  final ChartData data;
  final List<_AspectSegment> segments;

  _AspectsOnWheelPainter({required this.data, required this.segments});

  double _toRad(double deg) => deg * math.pi / 180.0;
  double _norm360(double deg) {
    var x = deg % 360.0;
    if (x < 0) x += 360.0;
    return x;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide * 0.38;

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..isAntiAlias = true;

    for (final s in segments) {
      final a1 = _toRad(_norm360(s.fromDeg - data.rotationCCWDeg));
      final a2 = _toRad(_norm360(s.toDeg - data.rotationCCWDeg));

      final p1 = center + Offset(math.cos(a1), math.sin(a1)) * r;
      final p2 = center + Offset(math.cos(a2), math.sin(a2)) * r;

      linePaint.color = s.color;
      canvas.drawLine(p1, p2, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AspectsOnWheelPainter old) =>
      old.segments != segments || old.data.rotationCCWDeg != data.rotationCCWDeg;
}

/// ================= מסך תחזית =================

class ForecastScreen extends StatefulWidget {
  final Map<String, dynamic> forecastData;
  final String birthDate;
  final String birthTime;
  final String tz;
  final String lat;
  final String lon;
  final HouseSystem houseSystem;

  const ForecastScreen({
    super.key,
    required this.forecastData,
    required this.birthDate,
    required this.birthTime,
    required this.tz,
    required this.lat,
    required this.lon,
    required this.houseSystem,
  });

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  bool showAllAspects = false;
  bool showWheelAspects = true;

  // ===== Retro/helpers =====
  bool _isRetro(String s) =>
      s.contains('℞') || RegExp(r'(^|\s)R(\s|$)', caseSensitive: false).hasMatch(s);

  String _cleanRetro(String s) {
    var out = s.replaceAll('℞', '');
    out = out.replaceAll(RegExp(r'(^|\s)R(\s|$)', caseSensitive: false), ' ');
    out = out.replaceAll(RegExp(r'\s+'), ' ').trim();
    return out;
  }

  WidgetSpan _rBoxSpan(Color c) => WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        baseline: TextBaseline.alphabetic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            border: Border.all(color: c, width: 1.3),
            borderRadius: BorderRadius.circular(4),
            color: c.withOpacity(0.10),
          ),
          child: Text(
            'R',
            style: TextStyle(
              color: c,
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
              height: 1.1,
            ),
          ),
        ),
      );

  List<InlineSpan> _nameWithR(String name, bool retro, Color color) {
    return [
      TextSpan(text: _cleanRetro(name)),
      if (retro) const TextSpan(text: ' '),
      if (retro) _rBoxSpan(color),
    ];
  }

  bool _retroFrom(dynamic v) => _isRetro(v?.toString() ?? '');

  // יוצרת וריאציות של מפתח כדי למצוא ב־flags גם אם הגיעו "☿ Mercury ℞" או "Mercury"
  Iterable<String> _keyVariants(String raw) sync* {
    final cleaned = raw
        .replaceAll('\u200f', '')
        .replaceAll('\u200e', '')
        .replaceAll('℞', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    yield cleaned;
    yield cleaned.replaceAll(' ', '');

    final canon = _canonPlanetName(cleaned);
    if (canon != null) yield canon;

    final tokens = <String>[];
    tokens.addAll(RegExp(r'[A-Za-z\u0590-\u05FF]+').allMatches(cleaned).map((m) => m.group(0)!));
    tokens.addAll(RegExp(r'[☉☽☿♀♂♃♄♅♆♇☊☋]').allMatches(cleaned).map((m) => m.group(0)!));
    for (final t in tokens) {
      yield t;
      final c = _canonPlanetName(t);
      if (c != null) yield c;
    }
  }

  bool _isRetroRobust(Map<String, dynamic> flags, String label, String value) {
    for (final k in _keyVariants(label)) {
      if (flags[k] == true) return true;
    }
    return _isRetro(label) || _isRetro(value);
  }

  static const Map<String, int> _signIndex = {
    'Aries': 0,
    'Taurus': 1,
    'Gemini': 2,
    'Cancer': 3,
    'Leo': 4,
    'Virgo': 5,
    'Libra': 6,
    'Scorpio': 7,
    'Sagittarius': 8,
    'Capricorn': 9,
    'Aquarius': 10,
    'Pisces': 11,
    'טלה': 0,
    'שור': 1,
    'תאומים': 2,
    'סרטן': 3,
    'אריה': 4,
    'בתולה': 5,
    'מאזניים': 6,
    'עקרב': 7,
    'קשת': 8,
    'גדי': 9,
    'דלי': 10,
    'דגים': 11,
  };

  double? _parseSignPosToDeg(String raw) {
    final s = raw.replaceAll('\u200f', '').trim();
    final regex = RegExp(r'([A-Za-z\u0590-\u05FF]+)\s+(\d{1,2})(?:[°\s]+(\d{1,2}))?');
    final m = regex.firstMatch(s);
    if (m == null) return null;
    final sign = m.group(1)!;
    final deg = int.tryParse(m.group(2) ?? '') ?? 0;
    final min = int.tryParse(m.group(3) ?? '0') ?? 0;
    final si = _signIndex.entries.firstWhere(
      (e) => sign.toLowerCase() == e.key.toLowerCase(),
      orElse: () => const MapEntry('', -1),
    ).value;
    if (si == -1) return null;
    return si * 30 + deg + min / 60.0;
  }

  double? _tryNum(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  String? _canonPlanetName(String k) {
    const aliases = <String, String>{
      'sun': 'Sun', '☉': 'Sun', 'שמש': 'Sun',
      'moon': 'Moon', '☽': 'Moon', 'ירח': 'Moon',
      'mercury': 'Mercury', '☿': 'Mercury', 'מרקורי': 'Mercury', 'כוכבחמה': 'Mercury',
      'venus': 'Venus', '♀': 'Venus', 'ונוס': 'Venus', 'נוגה': 'Venus',
      'mars': 'Mars', '♂': 'Mars', 'מאדים': 'Mars',
      'jupiter': 'Jupiter', '♃': 'Jupiter', 'יופיטר': 'Jupiter', 'צדק': 'Jupiter',
      'saturn': 'Saturn', '♄': 'Saturn', 'סטורן': 'Saturn', 'שבתאי': 'Saturn',
      'uranus': 'Uranus', '♅': 'Uranus', 'אורנוס': 'Uranus',
      'neptune': 'Neptune', '♆': 'Neptune', 'נפטון': 'Neptune',
      'pluto': 'Pluto', '♇': 'Pluto', 'פלוטו': 'Pluto',
      'asc': 'ASC', 'ascendant': 'ASC', 'אופק': 'ASC', 'אסצנדנט': 'ASC',
      'mc': 'MC', 'midheaven': 'MC', 'רוםהשמיים': 'MC', 'מרידיאן': 'MC',
      'truenode': 'Node', 'meannode': 'Node', 'node': 'Node', '☊': 'Node', 'ראשדרקון': 'Node',
      'southnode': 'South Node', '☋': 'South Node', 'זנבהדרקון': 'South Node',
    };

    String norm(String s) => s
        .replaceAll('\u200f', '')
        .replaceAll('\u200e', '')
        .replaceAll('℞', '')
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '');

    final n = norm(k);
    if (aliases.containsKey(n)) return aliases[n];

    final tokens = <String>[];
    tokens.addAll(RegExp(r'[A-Za-z\u0590-\u05FF]+').allMatches(k).map((m) => m.group(0)!));
    tokens.addAll(RegExp(r'[☉☽☿♀♂♃♄♅♆♇☊☋]').allMatches(k).map((m) => m.group(0)!));
    for (final t in tokens) {
      final tn = norm(t);
      if (aliases.containsKey(tn)) return aliases[tn];
    }
    return null;
  }

  double? _parseLonAny(dynamic v) {
    if (v == null) return null;
    return _tryNum(v) ?? _parseSignPosToDeg(v.toString());
  }

  ChartData? _buildChartData(Map<String, dynamic> f) {
    final natal = (f['natal'] as Map?)?.cast<String, dynamic>() ?? {};
    final transit = (f['transit'] as Map?)?.cast<String, dynamic>() ?? {};

    final tzLocation = tz.getLocation(widget.tz);
    final d = widget.birthDate.split('-');
    final t = widget.birthTime.split(':');
    final localDT = tz.TZDateTime(
      tzLocation,
      int.parse(d[0]),
      int.parse(d[1]),
      int.parse(d[2]),
      int.parse(t[0]),
      int.parse(t[1]),
    );
    final utcDT = localDT.toUtc();

    final lat = double.tryParse(widget.lat) ?? 0.0;
    final lon = double.tryParse(widget.lon) ?? 0.0;

    final am = AscMc.compute(utc: utcDT, latitude: lat, longitude: lon);
    final double ascDeg = am.ascDeg;
    final double? mcDeg = am.mcDeg;

    List<double>? houses;
    for (final key in ['natal_house_deg', 'natal_houses_deg', 'houses_deg', 'house_deg']) {
      final raw = f[key];
      if (raw is List && raw.length >= 12) {
        final vals = raw.map((e) => _tryNum(e) ?? 0.0).toList();
        houses = vals.take(12).toList();
        break;
      }
    }

    final natalPlanets = <PlanetPos>[];
    final transitPlanets = <PlanetPos>[];

    void addAllFrom(Map<String, dynamic> src, {required bool isTransit}) {
      src.forEach((k, v) {
        final c = _canonPlanetName(k);
        if (c == null || c == 'ASC' || c == 'MC') return;
        final lon = _parseLonAny(v);
        if (lon == null) return;

        final retroFlags = (isTransit ? f['transit_retro_flags'] : f['natal_retro_flags']);
        bool retroFlag = false;
        if (retroFlags is Map) {
          for (final kv in _keyVariants(k)) {
            if (retroFlags[kv] == true) {
              retroFlag = true;
              break;
            }
          }
        }

        (isTransit ? transitPlanets : natalPlanets).add(
          PlanetPos(
            name: c,
            lon: lon,
            retro: retroFlag || _retroFrom(v),
            isTransit: isTransit,
          ),
        );
      });
    }

    addAllFrom(natal, isTransit: false);
    addAllFrom(transit, isTransit: true);

    return ChartData(
      ascDeg: ascDeg,
      mcDeg: mcDeg,
      houseCusps: houses,
      planetsNatal: natalPlanets,
      planetsTransit: transitPlanets,
      houseSystem: widget.houseSystem,
      mirrorZodiacGlyphsVertically: true,
      aspectRadiusFactor: 0.32,
      aspectStrokeFactor: 0.0045,
      zodiacInnerFactor: 0.80,
      zodiacOuterFactor: 0.88,
      rotationCCWDeg: 0.0,
      showAscBadge: true,
    );
  }

  List<_AspectSegment> _buildAspectSegments(ChartData chart, List aspects) {
    final natalMap = {for (final p in chart.planetsNatal) p.name: p.lon};
    final transitMap = {for (final p in chart.planetsTransit) p.name: p.lon};

    String clean(String s) => s.replaceAll('℞', '').trim();

    final out = <_AspectSegment>[];
    for (final raw in aspects) {
      if (raw is! Map) continue;
      final a = raw.cast<String, dynamic>();

      final tNameRaw = clean((a['tPlanet'] ?? '').toString());
      final nNameRaw = clean((a['nPlanet'] ?? '').toString());
      final tName = _canonPlanetName(tNameRaw) ?? tNameRaw;
      final nName = _canonPlanetName(nNameRaw) ?? nNameRaw;

      double? tLon = transitMap[tName] ?? _parseLonAny(a['tPos']);
      double? nLon = natalMap[nName] ?? _parseLonAny(a['nPos']);
      if (tLon == null || nLon == null) continue;

      final asp = (a['aspect'] ?? '').toString();
      final label = '${_planetGlyph(tName)}  ${_aspectSymbol(asp)}  ${_planetGlyph(nName)}';

      out.add(_AspectSegment(
        fromDeg: tLon,
        toDeg: nLon,
        label: label,
        color: _aspectColor(asp),
      ));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    final Map<String, dynamic> natal =
        (widget.forecastData['natal'] as Map?)?.cast<String, dynamic>() ?? {};
    final Map<String, dynamic> transit =
        (widget.forecastData['transit'] as Map?)?.cast<String, dynamic>() ?? {};
    final List<dynamic> aspectsData =
        (widget.forecastData['aspects'] as List?) ?? [];

    final Map<String, dynamic> natalRetroRaw =
        (widget.forecastData['natal_retro_flags'] as Map?)?.cast<String, dynamic>() ?? const {};
    final Map<String, dynamic> transitRetroRaw =
        (widget.forecastData['transit_retro_flags'] as Map?)?.cast<String, dynamic>() ?? const {};

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

    Widget summaryPanel() {
      return _card(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _title(l.natal_title, Colors.amber),
                  if (natal.isEmpty)
                    const Text('-', style: TextStyle(color: Colors.white54))
                  else
                    ...natal.entries.map((e) {
                      final label = e.key.toString();
                      final value = e.value.toString();
                      final retro = _isRetroRobust(natalRetroRaw, label, value);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(color: Colors.white, height: 1.4),
                            children: [
                              ..._nameWithR(label, retro, Colors.amber),
                              const TextSpan(text: ': '),
                              TextSpan(text: _cleanRetro(value)),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _title(l.transit_title, Colors.lightBlueAccent),
                  if (transit.isEmpty)
                    const Text('-', style: TextStyle(color: Colors.white54))
                  else
                    ...transit.entries.map((e) {
                      final label = e.key.toString();
                      final value = e.value.toString();
                      final retro = _isRetroRobust(transitRetroRaw, label, value);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(color: Colors.white, height: 1.4),
                            children: [
                              ..._nameWithR(label, retro, Colors.lightBlueAccent),
                              const TextSpan(text: ': '),
                              TextSpan(text: _cleanRetro(value)),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget aspectsList(List aspects) {
      if (aspects.isEmpty) {
        return _card(
          child: Text(l.no_aspects, style: const TextStyle(color: Colors.white70)),
        );
      }
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
                icon: Icon(
                  showAllAspects ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: Colors.white70,
                ),
                label: Text(
                  showAllAspects ? l.show_less : l.show_all_aspects(aspects.length),
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
            const SizedBox(height: 4),
            ...List.generate(count, (i) {
              final a = (aspects[i] as Map).cast<String, dynamic>();
              final String rawTPlanet = (a['tPlanet'] ?? '').toString();
              final String rawNPlanet = (a['nPlanet'] ?? '').toString();
              final String tPlanet = _cleanRetro(rawTPlanet);
              final String nPlanet = _cleanRetro(rawNPlanet);
              final String aspect = (a['aspect'] ?? '').toString();
              final String orb = (a['orb'] ?? '').toString();
              final String tPos = _cleanRetro((a['tPos'] ?? '').toString());
              final String nPos = _cleanRetro((a['nPos'] ?? '').toString());

              final bool tRetro = _isRetroRobust(transitRetroRaw, rawTPlanet, (a['tPos'] ?? '').toString());
              final bool nRetro = _isRetroRobust(natalRetroRaw, rawNPlanet, (a['nPos'] ?? '').toString());

              return Column(
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.white, height: 1.5),
                      children: [
                        const TextSpan(text: '• '),
                        ..._nameWithR(tPlanet, tRetro, Colors.lightBlueAccent),
                        const TextSpan(text: ' (', style: TextStyle(color: Colors.white70)),
                        TextSpan(text: tPos, style: const TextStyle(color: Colors.white70)),
                        const TextSpan(text: ') - ', style: TextStyle(color: Colors.white70)),
                        TextSpan(text: aspect, style: TextStyle(color: _aspectColor(aspect), fontWeight: FontWeight.bold)),
                        TextSpan(text: ' ($orb°) - ', style: const TextStyle(color: Colors.white70)),
                        ..._nameWithR(nPlanet, nRetro, Colors.amber),
                        const TextSpan(text: ' (', style: TextStyle(color: Colors.white70)),
                        TextSpan(text: nPos, style: const TextStyle(color: Colors.white70)),
                        const TextSpan(text: ')', style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                  if (i < count - 1) const Divider(color: Colors.white12, height: 16),
                ],
              );
            }),
          ],
        ),
      );
    }

    Widget wheelCard() {
      final chart = _buildChartData(widget.forecastData);
      if (chart == null) {
        return _card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline, color: Colors.white70),
                const SizedBox(height: 8),
                Text(l.wheel_unavailable, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      }

      final segs = _buildAspectSegments(chart, aspectsData);

      return _card(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                AstroWheel(
                  data: chart,
                  size: 420,
                  fontScale: 1.05,
                  wheelScale: 1.0,
                  planetIcons: null,
                ),
                if (showWheelAspects && segs.isNotEmpty)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _AspectsOnWheelPainter(data: chart, segments: segs),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: () => setState(() => showWheelAspects = !showWheelAspects),
                icon: Icon(
                  showWheelAspects ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 18,
                  color: Colors.white70,
                ),
                label: Text(showWheelAspects ? l.hide_aspects : l.show_aspects, style: const TextStyle(color: Colors.white70)),
              ),
            ),
          ],
        ),
      );
    }

    Widget bottomLeftExtras() {
      final List<dynamic> lucky = (widget.forecastData['lucky_hours'] as List?) ?? [];
      String rng(Map e) => "🔸 ${e['from'] ?? ''} - ${e['to'] ?? ''}";

      final meta = l.meta_house_tz(widget.tz, houseSystemLabel(context, widget.houseSystem));

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(meta, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          Text(
            l.lucky_hours_title,
            style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (lucky.isEmpty)
            const Text("-", style: TextStyle(color: Colors.white54))
          else
            ...lucky.take(2).map((e) => Text(rng((e as Map)), style: const TextStyle(color: Colors.white))),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () async {
              if (Platform.isAndroid || Platform.isIOS) {
                await AdsService.showInterstitialIfNeeded(isPro: false);
              }
              if (!mounted) return;
              final lang = Localizations.localeOf(context).languageCode;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProForecastScreen(
                    birthDate: widget.birthDate,
                    birthTime: widget.birthTime,
                    tz: widget.tz,
                    lat: widget.lat,
                    lon: widget.lon,
                    lang: lang,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.workspace_premium),
            label: Text(l.open_pro_button),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.daily_forecast_title(widget.forecastData['date'] ?? '')),
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
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, cs) {
            final bool wide = cs.maxWidth >= 1100;

            final Widget aspectsWidget = aspectsList(aspectsData);
            final Widget wheelWidget = wheelCard();

            if (!wide) {
              return ListView(
                children: [
                  summaryPanel(),
                  const SizedBox(height: 16),
                  aspectsWidget,
                  const SizedBox(height: 16),
                  wheelWidget,
                  const SizedBox(height: 16),
                  bottomLeftExtras(),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: ListView(
                    children: [
                      summaryPanel(),
                      const SizedBox(height: 16),
                      bottomLeftExtras(),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(flex: 3, child: ListView(children: [aspectsWidget])),
                const SizedBox(width: 16),
                Expanded(flex: 4, child: Align(alignment: Alignment.topCenter, child: wheelWidget)),
              ],
            );
          },
        ),
      ),
    );
  }
}
