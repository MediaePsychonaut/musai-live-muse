import 'package:flutter/material.dart';

class BloomBorder extends StatelessWidget {
  final Widget child;
  final Color bloomColor;
  final double borderRadius;
  final double strokeWidth;
  final double blurRadius;

  const BloomBorder({
    super.key,
    required this.child,
    required this.bloomColor,
    this.borderRadius = 8.0,
    this.strokeWidth = 1.0,
    this.blurRadius = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BloomPainter(
        color: bloomColor,
        radius: borderRadius,
        strokeWidth: strokeWidth,
        blurRadius: blurRadius,
      ),
      child: child,
    );
  }
}

class _BloomPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;
  final double blurRadius;

  _BloomPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.blurRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    // 1. Draw the Bloom (Glow)
    final glowPaint = Paint()
      ..color = color.withAlpha(150) // Adjust opacity for "glow" feel
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurRadius);
    
    canvas.drawRRect(rrect, glowPaint);

    // 2. Draw the Sharp 1px Border
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    
    canvas.drawRRect(rrect, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _BloomPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.blurRadius != blurRadius;
  }
}
