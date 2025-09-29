// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'LOTTOLUCK';

  @override
  String get register_title => 'Register to LOTTOLUCK';

  @override
  String get tagline_connect_luck => '🧙‍♂️ Connect to your luck';

  @override
  String get first_name_label => 'First name';

  @override
  String get birth_date_label => 'Birth date';

  @override
  String get birth_time_label => 'Birth time';

  @override
  String get time_zone_label => 'Time zone (IANA)';

  @override
  String get house_system_label => 'House system';

  @override
  String city_selected_template(
      String city, String country, String lat, String lon) {
    return '$city, $country · Lat: $lat, Lon: $lon';
  }

  @override
  String get save_step1_button => 'Save step 1 (local)';

  @override
  String get show_forecast_button => 'Show forecast';

  @override
  String get form_incomplete_hint =>
      'Please fill name, city, date, time and time zone';

  @override
  String daily_forecast_title(String date) {
    return '🔮 Daily forecast • $date';
  }

  @override
  String get natal_title => '✨ Natal';

  @override
  String get transit_title => '🚀 Transit';

  @override
  String get no_aspects => 'No aspects in the defined orb range.';

  @override
  String show_all_aspects(int count) {
    return 'Show all $count aspects';
  }

  @override
  String get show_less => 'Show less';

  @override
  String get wheel_unavailable => 'Wheel view is not available.';

  @override
  String get hide_aspects => 'Hide aspects';

  @override
  String get show_aspects => 'Show aspects';

  @override
  String get lucky_hours_title => '🎯 Lucky hours (free – next 2 windows)';

  @override
  String get open_pro_button => 'Open full PRO screen';

  @override
  String get pro_only_snackbar =>
      'PRO screen is available to subscribers only.';

  @override
  String meta_house_tz(String tz, String house) {
    return 'TZ: $tz • Houses: $house';
  }

  @override
  String error_running_forecast(String error) {
    return 'Error running forecast: $error';
  }
}
