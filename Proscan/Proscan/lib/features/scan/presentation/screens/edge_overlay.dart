// features/scan/presentation/widgets/edge_overlay.dart
import 'package:flutter/material.dart';

class EdgeOverlay extends StatelessWidget {
  final List<Offset>? points;
  final Size size;

  const EdgeOverlay({super.key, required this.points, required this.size});

  @override
  Widget build(BuildContext context) {
    if (points == null || points!.length != 4) return const SizedBox.shrink();

    final scaledPoints = points!
        .map(
          (p) => Offset(
            (p.dx.clamp(0.0, 1.0)) * size.width,
            (p.dy.clamp(0.0, 1.0)) * size.height,
          ),
        )
        .toList(growable: false);

    return SizedBox(
      width: size.width,
      height: size.height,
      child: CustomPaint(painter: EdgePainter(scaledPoints)),
    );
  }
}

class EdgePainter extends CustomPainter {
  final List<Offset> points;

  EdgePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.4)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    final path = Path()
      ..moveTo(points[0].dx, points[0].dy)
      ..lineTo(points[1].dx, points[1].dy)
      ..lineTo(points[2].dx, points[2].dy)
      ..lineTo(points[3].dx, points[3].dy)
      ..close();

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);

    // Corner dots
    final solidPaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.fill;

    for (final p in points) {
      canvas.drawCircle(p, 20, glowPaint);
      canvas.drawCircle(p, 12, solidPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
