import 'package:flutter/material.dart';

class ForecastScreen extends StatelessWidget {
  const ForecastScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('תחזית אסטרולוגית'),
      ),
      body: const Center(
        child: Text(
          'כאן תופיע התחזית האסטרולוגית של היום',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}

