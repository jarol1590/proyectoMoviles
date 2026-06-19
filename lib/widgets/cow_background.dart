import 'package:flutter/material.dart';

class CowBackground extends StatelessWidget {
  final Widget child;
  const CowBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: CowSpotPainter(),
          ),
        ),
        SafeArea(child: child),
      ],
    );
  }
}

class CowSpotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[800]!
      ..style = PaintingStyle.fill;

    // Draw some random-ish spots to simulate the cow pattern
    _drawSpot(canvas, Offset(size.width * 0.1, size.height * 0.1), 60, 40);
    _drawSpot(canvas, Offset(size.width * 0.8, size.height * 0.05), 80, 100);
    _drawSpot(canvas, Offset(size.width * 0.5, size.height * 0.4), 120, 90);
    _drawSpot(canvas, Offset(size.width * -0.05, size.height * 0.6), 100, 150);
    _drawSpot(canvas, Offset(size.width * 0.9, size.height * 0.7), 70, 80);
    _drawSpot(canvas, Offset(size.width * 0.3, size.height * 0.9), 110, 60);
  }

  void _drawSpot(Canvas canvas, Offset center, double width, double height) {
    final paint = Paint()..color = Colors.grey[800]!;
    canvas.drawOval(
      Rect.fromCenter(center: center, width: width, height: height),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
