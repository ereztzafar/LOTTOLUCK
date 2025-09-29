import 'package:flutter/material.dart';
import '../widgets/CitySearchWidget.dart';
import '../models/city.dart';
import 'package:lottoluck/widgets/city_search_widget.dart';


class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController nameController = TextEditingController();
  DateTime? selectedDate;
  City? selectedCity;

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1970),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  void _submitForm() {
    if (nameController.text.isEmpty || selectedDate == null || selectedCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('נא למלא את כל השדות')),
      );
      return;
    }

    print('שם: ${nameController.text}');
    print('תאריך לידה: ${selectedDate.toString()}');
    print('עיר: ${selectedCity!.name}');
    print('Latitude: ${selectedCity!.latitude}');
    print('Longitude: ${selectedCity!.longitude}');

    // נוכל לשמור כאן SharedPreferences או לעבור למסך הבא
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('הרשמה'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "שם פרטי",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: Text(
                selectedDate == null
                    ? "בחר תאריך לידה"
                    : "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}",
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _selectDate,
            ),
            const SizedBox(height: 16),
            CitySearchWidget(
              onCitySelected: (city) {
                setState(() {
                  selectedCity = city;
                });
              },
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _submitForm,
              child: const Text('המשך'),
            ),
          ],
        ),
      ),
    );
  }
}
