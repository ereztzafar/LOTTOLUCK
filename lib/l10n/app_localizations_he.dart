// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class AppLocalizationsHe extends AppLocalizations {
  AppLocalizationsHe([String locale = 'he']) : super(locale);

  @override
  String get appTitle => 'LOTTOLUCK';

  @override
  String get register_title => 'הרשמה ל־LOTTOLUCK';

  @override
  String get tagline_connect_luck => '🧙‍♂️ התחבר למזל שלך';

  @override
  String get first_name_label => 'שם פרטי';

  @override
  String get birth_date_label => 'תאריך לידה';

  @override
  String get birth_time_label => 'שעת לידה';

  @override
  String get time_zone_label => 'אזור זמן (IANA)';

  @override
  String get house_system_label => 'שיטת חישוב בתים';

  @override
  String city_selected_template(
      String city, String country, String lat, String lon) {
    return '$city, $country · Lat: $lat, Lon: $lon';
  }

  @override
  String get save_step1_button => 'שמור שלב 1 (לוקאלי)';

  @override
  String get show_forecast_button => 'הצג תחזית';

  @override
  String get form_incomplete_hint => 'יש למלא שם, עיר, תאריך, שעה ואזור זמן';

  @override
  String daily_forecast_title(String date) {
    return '🔮 תחזית יומית • $date';
  }

  @override
  String get natal_title => '✨ לידה (Natal)';

  @override
  String get transit_title => '🚀 מעבר (Transit)';

  @override
  String get no_aspects => 'אין היבטים בטווח האורב שהוגדר.';

  @override
  String show_all_aspects(int count) {
    return 'הצג את כל $count ההיבטים';
  }

  @override
  String get show_less => 'הצג פחות';

  @override
  String get wheel_unavailable => 'תצוגת גלגל אינה זמינה.';

  @override
  String get hide_aspects => 'הסתר אספקטים';

  @override
  String get show_aspects => 'הצג אספקטים';

  @override
  String get lucky_hours_title => '🎯 שעות מזל (חינמי – 2 חלונות קרובים)';

  @override
  String get open_pro_button => 'פתח מסך PRO המלא';

  @override
  String get pro_only_snackbar => 'מסך PRO זמין למנויים בלבד.';

  @override
  String meta_house_tz(String tz, String house) {
    return 'TZ: $tz • בתים: $house';
  }

  @override
  String error_running_forecast(String error) {
    return 'שגיאה בהרצת התחזית: $error';
  }
}
