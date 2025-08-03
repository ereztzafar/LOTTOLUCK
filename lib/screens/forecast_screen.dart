import 'package:flutter/material.dart';

class ForecastScreen extends StatelessWidget {
  final String name;
  final String date;
  final String time;
  final String city;

  const ForecastScreen({
    super.key,
    required this.name,
    required this.date,
    required this.time,
    required this.city,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('תחזית אסטרולוגית'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'פרטים שהוזנו:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text('👤 שם: $name'),
            Text('📅 תאריך לידה: $date'),
            Text('⏰ שעת לידה: $time'),
            Text('🌍 עיר לידה: $city'),
            const SizedBox(height: 30),
            const Text(
              '🔮 תחזית היומית שלך תופיע כאן בקרוב...',
              style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}


