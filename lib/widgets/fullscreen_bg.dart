import 'package:flutter/material.dart';

class FullScreenBg extends StatelessWidget {
  final Widget child;
  const FullScreenBg({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // תמונה מכסה את כל המסך
        Image.asset(
          'assets/images/lucky_balls_full.png',
          fit: BoxFit.cover,
        ),
        // שכבת כהות עדינה אם צריך קריאות טקסט
        Container(color: Colors.black.withOpacity(0.08)),
        child,
      ],
    );
  }
}
