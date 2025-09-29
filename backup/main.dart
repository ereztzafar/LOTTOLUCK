import 'package:flutter/material.dart';

void main() {
  runApp(LottoLuckApp());
}

class LottoLuckApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lotto Luck',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: BirthFormScreen(),
    );
  }
}

class BirthFormScreen extends StatefulWidget {
  @override
  _BirthFormScreenState createState() => _BirthFormScreenState();
}

class _BirthFormScreenState extends State<BirthFormScreen> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  DateTime? _birthDate;
  TimeOfDay? _birthTime;
  String _birthCity = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('🪐 הזן פרטי לידה')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: 'שם פרטי'),
                onChanged: (value) => _name = value,
              ),
              SizedBox(height: 10),
              ListTile(
                title: Text(_birthDate == null
                    ? 'בחר תאריך לידה'
                    : 'תאריך לידה: ${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}'),
                trailing: Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime(1970),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) setState(() => _birthDate = date);
                },
              ),
              ListTile(
                title: Text(_birthTime == null
                    ? 'בחר שעה'
                    : 'שעה: ${_birthTime!.format(context)}'),
                trailing: Icon(Icons.access_time),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(hour: 6, minute: 0),
                  );
                  if (time != null) setState(() => _birthTime = time);
                },
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'עיר לידה'),
                onChanged: (value) => _birthCity = value,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                child: Text('שלח'),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    print('📋 שם: $_name');
                    print('📅 תאריך: $_birthDate');
                    print('🕓 שעה: $_birthTime');
                    print('🌍 עיר: $_birthCity');
                    // נשלב כאן את שלב החישוב האסטרולוגי בהמשך
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
