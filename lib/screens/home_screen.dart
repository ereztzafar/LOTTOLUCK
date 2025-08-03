import 'package:flutter/material.dart';
import 'forecast_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final dateController = TextEditingController();
  final timeController = TextEditingController();
  final cityController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    dateController.dispose();
    timeController.dispose();
    cityController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final name = nameController.text;
      final date = dateController.text;
      final time = timeController.text;
      final city = cityController.text;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ForecastScreen(
            name: name,
            date: date,
            time: time,
            city: city,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🔮 AstroLotto')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'שם מלא'),
                validator: (value) => value!.isEmpty ? 'הכנס שם' : null,
              ),
              TextFormField(
                controller: dateController,
                decoration: const InputDecoration(labelText: 'תאריך לידה (YYYY/MM/DD)'),
                validator: (value) => value!.isEmpty ? 'הכנס תאריך' : null,
              ),
              TextFormField(
                controller: timeController,
                decoration: const InputDecoration(labelText: 'שעת לידה (HH:MM)'),
                validator: (value) => value!.isEmpty ? 'הכנס שעה' : null,
              ),
              TextFormField(
                controller: cityController,
                decoration: const InputDecoration(labelText: 'עיר לידה'),
                validator: (value) => value!.isEmpty ? 'הכנס עיר' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitForm,
                child: const Text('🔍 בדוק מזל'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
