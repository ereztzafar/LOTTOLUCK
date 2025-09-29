// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'LOTTOLUCK';

  @override
  String get register_title => 'Регистрация в LOTTOLUCK';

  @override
  String get tagline_connect_luck => '🧙‍♂️ Подключись к своей удаче';

  @override
  String get first_name_label => 'Имя';

  @override
  String get birth_date_label => 'Дата рождения';

  @override
  String get birth_time_label => 'Время рождения';

  @override
  String get time_zone_label => 'Часовой пояс (IANA)';

  @override
  String get house_system_label => 'Система домов';

  @override
  String city_selected_template(
      String city, String country, String lat, String lon) {
    return '$city, $country · Шир: $lat, Долг: $lon';
  }

  @override
  String get save_step1_button => 'Сохранить шаг 1 (локально)';

  @override
  String get show_forecast_button => 'Показать прогноз';

  @override
  String get form_incomplete_hint =>
      'Заполните имя, город, дату, время и часовой пояс';

  @override
  String daily_forecast_title(String date) {
    return '🔮 Ежедневный прогноз • $date';
  }

  @override
  String get natal_title => '✨ Натал';

  @override
  String get transit_title => '🚀 Транзит';

  @override
  String get no_aspects => 'Нет аспектов в заданном орбе.';

  @override
  String show_all_aspects(int count) {
    return 'Показать все аспекты ($count)';
  }

  @override
  String get show_less => 'Показать меньше';

  @override
  String get wheel_unavailable => 'Вид колеса недоступен.';

  @override
  String get hide_aspects => 'Скрыть аспекты';

  @override
  String get show_aspects => 'Показать аспекты';

  @override
  String get lucky_hours_title =>
      '🎯 Счастливые часы (бесплатно – ближайшие 2 окна)';

  @override
  String get open_pro_button => 'Открыть полный экран PRO';

  @override
  String get pro_only_snackbar => 'Экран PRO доступен только подписчикам.';

  @override
  String meta_house_tz(String tz, String house) {
    return 'Пояс: $tz • Дома: $house';
  }

  @override
  String error_running_forecast(String error) {
    return 'Ошибка выполнения прогноза: $error';
  }
}
