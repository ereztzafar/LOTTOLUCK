// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'LOTTOLUCK';

  @override
  String get register_title => 'Inscription à LOTTOLUCK';

  @override
  String get tagline_connect_luck => '🧙‍♂️ Connectez-vous à votre chance';

  @override
  String get first_name_label => 'Prénom';

  @override
  String get birth_date_label => 'Date de naissance';

  @override
  String get birth_time_label => 'Heure de naissance';

  @override
  String get time_zone_label => 'Fuseau horaire (IANA)';

  @override
  String get house_system_label => 'Système des maisons';

  @override
  String city_selected_template(
      String city, String country, String lat, String lon) {
    return '$city, $country · Lat : $lat, Lon : $lon';
  }

  @override
  String get save_step1_button => 'Enregistrer l’étape 1 (local)';

  @override
  String get show_forecast_button => 'Afficher le prévisionnel';

  @override
  String get form_incomplete_hint =>
      'Veuillez renseigner le nom, la ville, la date, l’heure et le fuseau horaire';

  @override
  String daily_forecast_title(String date) {
    return '🔮 Prévision du jour • $date';
  }

  @override
  String get natal_title => '✨ Natal';

  @override
  String get transit_title => '🚀 Transit';

  @override
  String get no_aspects => 'Aucun aspect dans l’orbe défini.';

  @override
  String show_all_aspects(int count) {
    return 'Afficher les $count aspects';
  }

  @override
  String get show_less => 'Afficher moins';

  @override
  String get wheel_unavailable => 'La roue n’est pas disponible.';

  @override
  String get hide_aspects => 'Masquer les aspects';

  @override
  String get show_aspects => 'Afficher les aspects';

  @override
  String get lucky_hours_title =>
      '🎯 Heures porte-bonheur (gratuit – 2 prochains créneaux)';

  @override
  String get open_pro_button => 'Ouvrir l’écran PRO complet';

  @override
  String get pro_only_snackbar => 'L’écran PRO est réservé aux abonnés.';

  @override
  String meta_house_tz(String tz, String house) {
    return 'TZ : $tz • Maisons : $house';
  }

  @override
  String error_running_forecast(String error) {
    return 'Erreur lors de l’exécution du prévisionnel : $error';
  }
}
