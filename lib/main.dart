import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/forecast_screen.dart';

void main() {
  runApp(const AstroLottoApp());
}

class AstroLottoApp extends StatelessWidget {
  const AstroLottoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AstroLotto',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const HomeScreen(),
      routes: {
        '/forecast': (context) => const ForecastScreen(),
      },
    );
  }
}


