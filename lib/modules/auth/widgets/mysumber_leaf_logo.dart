import 'package:flutter/material.dart';

/// Two-leaf brand mark: a lighter mint leaf tucked in front of a taller,
/// darker leaf, both rising from a shared base with a center vein and a
/// thin highlight stroke — approximated with bezier paths since no source
/// vector asset was supplied.
class MySumberLeafLogo extends StatelessWidget {
  final double size;
  const MySumberLeafLogo({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.92,
      child: CustomPaint(painter: _LeafLogoPainter()),
    );
  }
}

class _LeafLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final leftBase = Offset(w * 0.50, h * 0.97);
    final leftTip = Offset(w * 0.20, h * 0.30);
    final leftPath = Path()
      ..moveTo(leftBase.dx, leftBase.dy)
      ..cubicTo(
        w * 0.06, h * 0.78,
        w * 0.00, h * 0.42,
        leftTip.dx, leftTip.dy,
      )
      ..cubicTo(
        w * 0.32, h * 0.42,
        w * 0.46, h * 0.72,
        leftBase.dx, leftBase.dy,
      )
      ..close();

    final rightBase = Offset(w * 0.52, h * 1.0);
    final rightTip = Offset(w * 0.84, h * 0.03);
    final rightPath = Path()
      ..moveTo(rightBase.dx, rightBase.dy)
      ..cubicTo(
        w * 0.34, h * 0.72,
        w * 0.28, h * 0.28,
        rightTip.dx, rightTip.dy,
      )
      ..cubicTo(
        w * 0.78, h * 0.26,
        w * 0.97, h * 0.62,
        rightBase.dx, rightBase.dy,
      )
      ..close();

    final leftPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topLeft,
        colors: [Color(0xFF34D399), Color(0xFF6EE7A0)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final rightPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomRight,
        end: Alignment.topLeft,
        colors: [Color(0xFF15803D), Color(0xFF22C55E)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(leftPath, leftPaint);
    canvas.drawPath(rightPath, rightPaint);

    final veinPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.016
      ..strokeCap = StrokeCap.round;

    final leftVein = Path()
      ..moveTo(leftBase.dx - w * 0.015, leftBase.dy - h * 0.08)
      ..quadraticBezierTo(
        w * 0.20, h * 0.58,
        leftTip.dx + w * 0.035, leftTip.dy + h * 0.08,
      );
    final rightVein = Path()
      ..moveTo(rightBase.dx + w * 0.01, rightBase.dy - h * 0.10)
      ..quadraticBezierTo(
        w * 0.56, h * 0.52,
        rightTip.dx - w * 0.02, rightTip.dy + h * 0.10,
      );

    canvas.drawPath(leftVein, veinPaint);
    canvas.drawPath(rightVein, veinPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
