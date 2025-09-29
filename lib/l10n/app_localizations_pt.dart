// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'LOTTOLUCK';

  @override
  String get register_title => 'Registro no LOTTOLUCK';

  @override
  String get tagline_connect_luck => '🧙‍♂️ Conecte-se à sua sorte';

  @override
  String get first_name_label => 'Nome';

  @override
  String get birth_date_label => 'Data de nascimento';

  @override
  String get birth_time_label => 'Hora de nascimento';

  @override
  String get time_zone_label => 'Fuso horário (IANA)';

  @override
  String get house_system_label => 'Sistema de casas';

  @override
  String city_selected_template(
      String city, String country, String lat, String lon) {
    return '$city, $country · Lat: $lat, Lon: $lon';
  }

  @override
  String get save_step1_button => 'Salvar etapa 1 (local)';

  @override
  String get show_forecast_button => 'Mostrar previsão';

  @override
  String get form_incomplete_hint =>
      'Preencha nome, cidade, data, hora e fuso horário';

  @override
  String daily_forecast_title(String date) {
    return '🔮 Previsão diária • $date';
  }

  @override
  String get natal_title => '✨ Natal';

  @override
  String get transit_title => '🚀 Trânsito';

  @override
  String get no_aspects => 'Sem aspectos no orbe definido.';

  @override
  String show_all_aspects(int count) {
    return 'Mostrar todos os $count aspectos';
  }

  @override
  String get show_less => 'Mostrar menos';

  @override
  String get wheel_unavailable => 'A visualização da roda não está disponível.';

  @override
  String get hide_aspects => 'Ocultar aspectos';

  @override
  String get show_aspects => 'Mostrar aspectos';

  @override
  String get lucky_hours_title =>
      '🎯 Horas da sorte (grátis – 2 próximas janelas)';

  @override
  String get open_pro_button => 'Abrir tela PRO completa';

  @override
  String get pro_only_snackbar =>
      'A tela PRO está disponível apenas para assinantes.';

  @override
  String meta_house_tz(String tz, String house) {
    return 'TZ: $tz • Casas: $house';
  }

  @override
  String error_running_forecast(String error) {
    return 'Erro ao executar a previsão: $error';
  }
}
