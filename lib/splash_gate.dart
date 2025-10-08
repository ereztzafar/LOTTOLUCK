import 'dart:async';
import 'package:flutter/material.dart';

class SplashGate extends StatefulWidget {
  const SplashGate({super.key});
  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  String? _asset; // ייבחר לפי יחס המסך

  @override
  void initState() {
    super.initState();
    // קובע את הנכס אחרי שיש לנו MediaQuery
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final size = MediaQuery.of(context).size;
      final chosen = _pickSplashAsset(size);
      // טעינה מוקדמת למניעת הבהוב
      await precacheImage(AssetImage(chosen), context);
      if (!mounted) return;
      setState(() => _asset = chosen);

      // מעבר מהיר למסך הבא
      Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/register');
      });
    });
  }

  // בוחר את הווריאציה הקרובה ביותר ליחס המסך בפועל
  String _pickSplashAsset(Size size) {
    final ratio = size.height / size.width; // יחס גובה-רוחב
    final candidates = <String, double>{
      'assets/images/splash_20_9.png'   : 20 / 9,    // 2.222...
      'assets/images/splash_19_5_9.png' : 19.5 / 9,  // 2.166...
      'assets/images/splash_16_9.png'   : 16 / 9,    // 1.777...
    };
    String best = candidates.keys.first;
    double bestDiff = double.infinity;
    candidates.forEach((path, r) {
      final d = (r - ratio).abs();
      if (d < bestDiff) {
        bestDiff = d;
        best = path;
      }
    });
    return best;
  }

  @override
  Widget build(BuildContext context) {
    // אם עוד לא בחרנו נכס - רקע צבעוני קצר
    if (_asset == null) {
      return const Scaffold(backgroundColor: Color(0xFF5B2C98));
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // תמונה מלאה ללא מתיחה - BoxFit.cover ממלא ומחסיר שוליים אם צריך
          Image.asset(_asset!, fit: BoxFit.cover),
          // אופציונלי: הילה כהה עדינה
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0x20000000)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
