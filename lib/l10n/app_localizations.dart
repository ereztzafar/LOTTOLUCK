import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_he.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('he'),
    Locale('pt'),
    Locale('ru')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'LOTTOLUCK'**
  String get appTitle;

  /// No description provided for @register_title.
  ///
  /// In en, this message translates to:
  /// **'Register to LOTTOLUCK'**
  String get register_title;

  /// No description provided for @tagline_connect_luck.
  ///
  /// In en, this message translates to:
  /// **'🧙‍♂️ Connect to your luck'**
  String get tagline_connect_luck;

  /// No description provided for @first_name_label.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get first_name_label;

  /// No description provided for @birth_date_label.
  ///
  /// In en, this message translates to:
  /// **'Birth date'**
  String get birth_date_label;

  /// No description provided for @birth_time_label.
  ///
  /// In en, this message translates to:
  /// **'Birth time'**
  String get birth_time_label;

  /// No description provided for @time_zone_label.
  ///
  /// In en, this message translates to:
  /// **'Time zone (IANA)'**
  String get time_zone_label;

  /// No description provided for @house_system_label.
  ///
  /// In en, this message translates to:
  /// **'House system'**
  String get house_system_label;

  /// No description provided for @city_selected_template.
  ///
  /// In en, this message translates to:
  /// **'{city}, {country} · Lat: {lat}, Lon: {lon}'**
  String city_selected_template(
      String city, String country, String lat, String lon);

  /// No description provided for @save_step1_button.
  ///
  /// In en, this message translates to:
  /// **'Save step 1 (local)'**
  String get save_step1_button;

  /// No description provided for @show_forecast_button.
  ///
  /// In en, this message translates to:
  /// **'Show forecast'**
  String get show_forecast_button;

  /// No description provided for @form_incomplete_hint.
  ///
  /// In en, this message translates to:
  /// **'Please fill name, city, date, time and time zone'**
  String get form_incomplete_hint;

  /// No description provided for @daily_forecast_title.
  ///
  /// In en, this message translates to:
  /// **'🔮 Daily forecast • {date}'**
  String daily_forecast_title(String date);

  /// No description provided for @natal_title.
  ///
  /// In en, this message translates to:
  /// **'✨ Natal'**
  String get natal_title;

  /// No description provided for @transit_title.
  ///
  /// In en, this message translates to:
  /// **'🚀 Transit'**
  String get transit_title;

  /// No description provided for @no_aspects.
  ///
  /// In en, this message translates to:
  /// **'No aspects in the defined orb range.'**
  String get no_aspects;

  /// No description provided for @show_all_aspects.
  ///
  /// In en, this message translates to:
  /// **'Show all {count} aspects'**
  String show_all_aspects(int count);

  /// No description provided for @show_less.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get show_less;

  /// No description provided for @wheel_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Wheel view is not available.'**
  String get wheel_unavailable;

  /// No description provided for @hide_aspects.
  ///
  /// In en, this message translates to:
  /// **'Hide aspects'**
  String get hide_aspects;

  /// No description provided for @show_aspects.
  ///
  /// In en, this message translates to:
  /// **'Show aspects'**
  String get show_aspects;

  /// No description provided for @lucky_hours_title.
  ///
  /// In en, this message translates to:
  /// **'🎯 Lucky hours (free – next 2 windows)'**
  String get lucky_hours_title;

  /// No description provided for @open_pro_button.
  ///
  /// In en, this message translates to:
  /// **'Open full PRO screen'**
  String get open_pro_button;

  /// No description provided for @pro_only_snackbar.
  ///
  /// In en, this message translates to:
  /// **'PRO screen is available to subscribers only.'**
  String get pro_only_snackbar;

  /// No description provided for @meta_house_tz.
  ///
  /// In en, this message translates to:
  /// **'TZ: {tz} • Houses: {house}'**
  String meta_house_tz(String tz, String house);

  /// No description provided for @error_running_forecast.
  ///
  /// In en, this message translates to:
  /// **'Error running forecast: {error}'**
  String error_running_forecast(String error);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'ar',
        'en',
        'es',
        'fr',
        'he',
        'pt',
        'ru'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'he':
      return AppLocalizationsHe();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
