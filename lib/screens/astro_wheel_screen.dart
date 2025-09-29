// lib/screens/astro_wheel_screen.dart
import 'package:flutter/material.dart';
import '../widgets/astro_wheel.dart';            // המאוחד (מעודכן)
import '../widgets/astro_wheel_layers.dart';    // הגרסה בשכבות

class AstroWheelScreen extends StatelessWidget {
  const AstroWheelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // דוגמה: ASC 25° בעקרב, MC לדוגמה
    final asc = 235.0;
    final mc  = 325.0;

    // נתונים לדוגמה
    final natal = [
      PlanetPos(name: 'Sun', lon: 239),
      PlanetPos(name: 'Moon', lon: 12),
      PlanetPos(name: 'Mars', lon: 318),
    ];
    final trans = [
      PlanetPos(name: 'Sun', lon: 166),
      PlanetPos(name: 'Mars', lon: 93),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Astro Wheel')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // גרסת שכבות (מומלץ לפיתוח בשלבים)
            AstroWheelLayered(
              spec: WheelSpec(ascDeg: asc, mcDeg: mc),
              natal: natal,
              transits: trans,
              showDSCIC: true,
              size: 380,
            ),
            const SizedBox(height: 24),
            // הגרסה המאוחדת (הקובץ המעודכן שקיבלת)
            AstroWheel(
              data: ChartData(
                ascDeg: asc,
                mcDeg: mc,
                planetsNatal: natal,
                planetsTransit: trans,
                houseSystem: HouseSystem.equal,
                zodiacGoesCCWFromAsc: true,
              ),
              size: 360,
            ),
          ],
        ),
      ),
    );
  }
}
