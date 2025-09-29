import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/birth_profile.dart';
import '../services/birth_profile_store.dart';

class OnboardingWizard extends StatefulWidget {
  const OnboardingWizard({super.key});

  @override
  State<OnboardingWizard> createState() => _OnboardingWizardState();
}

class _OnboardingWizardState extends State<OnboardingWizard> {
  final _formKey = GlobalKey<FormState>();
  final _dateCtrl = TextEditingController(text: '22/11/1970');
  final _timeCtrl = TextEditingController(text: '06:00');

  // בחירה בסיסית לעיר; אפשר להחליף אח"כ ל-CitySearchWidget שלך.
  String? _cityName;
  double? _lat, _lon;
  String _tzId = 'Asia/Jerusalem'; // לישראל

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final init = DateFormat('dd/MM/yyyy').parse(_dateCtrl.text);
    final d = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'בחר תאריך לידה',
      locale: const Locale('he'),
    );
    if (d != null) {
      _dateCtrl.text = DateFormat('dd/MM/yyyy').format(d);
      setState(() {});
    }
  }

  Future<void> _pickTime() async {
    final init = DateFormat('HH:mm').parse(_timeCtrl.text);
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: init.hour, minute: init.minute),
      helpText: 'בחר שעה',
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t != null) {
      _timeCtrl.text =
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      setState(() {});
    }
  }

  Future<void> _pickCity() async {
    // TODO: להחליף ל-CitySearchWidget שלך. זמנית: "פתח תקוה".
    setState(() {
      _cityName = 'פתח תקוה';
      _lat = 32.087;
      _lon = 34.887;
      _tzId = 'Asia/Jerusalem';
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cityName == null || _lat == null || _lon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('בחר/י עיר מהרשימה')),
      );
      return;
    }

    final profile = BirthProfile(
      cityName: _cityName!,
      lat: _lat!,
      lon: _lon!,
      tzId: _tzId,
      birthDateDmy: _dateCtrl.text,
      birthTimeHm: _timeCtrl.text,
    );

    await BirthProfileStore.save(profile);
    if (!mounted) return;
    Navigator.of(context).pop(profile);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('פרטי לידה')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              readOnly: true,
              controller: TextEditingController(text: _cityName ?? ''),
              decoration: const InputDecoration(
                labelText: 'עיר לידה',
                hintText: 'למשל: פתח תקוה',
              ),
              onTap: _pickCity,
              validator: (v) => (v == null || v.isEmpty) ? 'חובה לבחור עיר' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dateCtrl,
              readOnly: true,
              decoration: const InputDecoration(labelText: 'תאריך לידה (dd/MM/yyyy)'),
              onTap: _pickDate,
              validator: (v) {
                try { DateFormat('dd/MM/yyyy').parseStrict(v ?? ''); return null; }
                catch (_) { return 'תאריך לא תקין'; }
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _timeCtrl,
              readOnly: true,
              decoration: const InputDecoration(labelText: 'שעת לידה (HH:mm)'),
              onTap: _pickTime,
              validator: (v) {
                try { DateFormat('HH:mm').parseStrict(v ?? ''); return null; }
                catch (_) { return 'שעה לא תקינה'; }
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _save,
              child: const Text('שמירה והמשך'),
            ),
          ],
        ),
      ),
    );
  }
}
