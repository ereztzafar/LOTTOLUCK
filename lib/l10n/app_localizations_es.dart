// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'LOTTOLUCK';

  @override
  String get register_title => 'Registro en LOTTOLUCK';

  @override
  String get tagline_connect_luck => '🧙‍♂️ Conéctate con tu suerte';

  @override
  String get first_name_label => 'Nombre';

  @override
  String get birth_date_label => 'Fecha de nacimiento';

  @override
  String get birth_time_label => 'Hora de nacimiento';

  @override
  String get time_zone_label => 'Zona horaria (IANA)';

  @override
  String get house_system_label => 'Sistema de casas';

  @override
  String city_selected_template(
      String city, String country, String lat, String lon) {
    return '$city, $country · Lat: $lat, Lon: $lon';
  }

  @override
  String get save_step1_button => 'Guardar paso 1 (local)';

  @override
  String get show_forecast_button => 'Mostrar pronóstico';

  @override
  String get form_incomplete_hint =>
      'Complete nombre, ciudad, fecha, hora y zona horaria';

  @override
  String daily_forecast_title(String date) {
    return '🔮 Pronóstico diario • $date';
  }

  @override
  String get natal_title => '✨ Natal';

  @override
  String get transit_title => '🚀 Tránsito';

  @override
  String get no_aspects => 'No hay aspectos en el orbe definido.';

  @override
  String show_all_aspects(int count) {
    return 'Mostrar los $count aspectos';
  }

  @override
  String get show_less => 'Mostrar menos';

  @override
  String get wheel_unavailable => 'La vista de rueda no está disponible.';

  @override
  String get hide_aspects => 'Ocultar aspectos';

  @override
  String get show_aspects => 'Mostrar aspectos';

  @override
  String get lucky_hours_title =>
      '🎯 Horas de suerte (gratis – 2 próximas ventanas)';

  @override
  String get open_pro_button => 'Abrir pantalla PRO completa';

  @override
  String get pro_only_snackbar =>
      'La pantalla PRO está disponible solo para suscriptores.';

  @override
  String meta_house_tz(String tz, String house) {
    return 'TZ: $tz • Casas: $house';
  }

  @override
  String error_running_forecast(String error) {
    return 'Error al ejecutar el pronóstico: $error';
  }
}
