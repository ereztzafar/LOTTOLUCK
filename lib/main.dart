import 'package:flutter/material.dart';

void main() {
  runApp(const AstroLottoApp());
}

class AstroLottoApp extends StatelessWidget {
  const AstroLottoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AstroLotto',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        fontFamily: 'Arial',
      ),
      home: const BirthDataForm(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class BirthDataForm extends StatefulWidget {
  const BirthDataForm({super.key});

  @override
  State<BirthDataForm> createState() => _BirthDataFormState();
}

class _BirthDataFormState extends State<BirthDataForm> {
  final nameController = TextEditingController();
  final dateController = TextEditingController();
  final timeController = TextEditingController();
  final cityController = TextEditingController();

  String result = '';

  void calculateLuckyHours() {
    setState(() {
      result = '✅ היום כדאי למלא לוטו בין 09:15–10:00 ובין 17:30–18:10!';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AstroLotto - תחזית מזל')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'שם פרטי'),
            ),
            TextField(
              controller: dateController,
              decoration: const InputDecoration(labelText: 'תאריך לידה (DD/MM/YYYY)'),
            ),
            TextField(
              controller: timeController,
              decoration: const InputDecoration(labelText: 'שעת לידה (HH:MM)'),
            ),
            TextField(
              controller: cityController,
              decoration: const InputDecoration(labelText: 'עיר לידה'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: calculateLuckyHours,
              child: const Text('קבל תחזית 🪐'),
            ),
            const SizedBox(height: 20),
            Text(
              result,
              style: const TextStyle(fontSize: 18, color: Colors.green),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
