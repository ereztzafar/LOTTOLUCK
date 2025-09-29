// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'LOTTOLUCK';

  @override
  String get register_title => 'التسجيل في LOTTOLUCK';

  @override
  String get tagline_connect_luck => '🧙‍♂️ اتصل بحظك';

  @override
  String get first_name_label => 'الاسم الأول';

  @override
  String get birth_date_label => 'تاريخ الميلاد';

  @override
  String get birth_time_label => 'وقت الميلاد';

  @override
  String get time_zone_label => 'المنطقة الزمنية (IANA)';

  @override
  String get house_system_label => 'نظام البيوت';

  @override
  String city_selected_template(
      String city, String country, String lat, String lon) {
    return '$city، $country · خط العرض: $lat، خط الطول: $lon';
  }

  @override
  String get save_step1_button => 'حفظ المرحلة 1 (محلي)';

  @override
  String get show_forecast_button => 'عرض التوقع';

  @override
  String get form_incomplete_hint =>
      'يرجى ملء الاسم، المدينة، التاريخ، الوقت والمنطقة الزمنية';

  @override
  String daily_forecast_title(String date) {
    return '🔮 التوقع اليومي • $date';
  }

  @override
  String get natal_title => '✨ الولادة (Natal)';

  @override
  String get transit_title => '🚀 العبور (Transit)';

  @override
  String get no_aspects => 'لا توجد زوايا ضمن مدى الأورب المحدد.';

  @override
  String show_all_aspects(int count) {
    return 'عرض جميع الزوايا ($count)';
  }

  @override
  String get show_less => 'عرض أقل';

  @override
  String get wheel_unavailable => 'عرض العجلة غير متاح.';

  @override
  String get hide_aspects => 'إخفاء الزوايا';

  @override
  String get show_aspects => 'إظهار الزوايا';

  @override
  String get lucky_hours_title => '🎯 ساعات الحظ (مجاني – أقرب نافذتين)';

  @override
  String get open_pro_button => 'افتح شاشة PRO الكاملة';

  @override
  String get pro_only_snackbar => 'شاشة PRO متاحة للمشتركين فقط.';

  @override
  String meta_house_tz(String tz, String house) {
    return 'المنطقة: $tz • البيوت: $house';
  }

  @override
  String error_running_forecast(String error) {
    return 'خطأ أثناء تشغيل التوقع: $error';
  }
}
