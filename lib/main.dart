import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const AstroLottoApp());
}

class AstroLottoApp extends StatelessWidget {
  const AstroLottoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AstroLotto',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
