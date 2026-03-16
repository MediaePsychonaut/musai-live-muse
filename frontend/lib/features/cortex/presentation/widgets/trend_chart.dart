import 'package:flutter/material.dart';
import '../../../../core/theme/musai_theme.dart';
import 'dart:math' as math;

class TrendChart extends StatelessWidget {
  final List<double> telemetry;
  final Color color;

  const TrendChart({
    super.key,
    required this.telemetry,
    this.color = MusaiTheme.deepSpaceTeal,
  });

  @override
  Widget build(BuildContext context) {
    if (telemetry.isEmpty) {
      return const Center(
        child: Text(
          "NO DATA TO VISUALIZE",
          style: TextStyle(color: Colors.white12, letterSpacing: 2, fontSize: 10),
        ),
      );
    }

    // IQR Filter to remove noise
    List<double> filterOutliers(List<double> data) {
      if (data.length < 4) return data;
      final sorted = List<double>.from(data)..sort();
      final q1 = sorted[(sorted.length * 0.25).floor()];
      final q3 = sorted[(sorted.length * 0.75).floor()];
      final iqr = q3 - q1;
      final margin = math.max(iqr * 1.5, 10.0);
      return data.where((v) => v >= q1 - margin && v <= q3 + margin).toList();
    }

    final filtered = filterOutliers(telemetry);

    return ClipRect(
      child: CustomPaint(
        size: Size.infinite,
        painter: _SmoothTrendPainter(
          dataPoints: filtered,
          color: color,
        ),
      ),
    );
  }
}

class _SmoothTrendPainter extends CustomPainter {
  final List<double> dataPoints;
  final Color color;

  _SmoothTrendPainter({required this.dataPoints, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.length < 2) return;

    double maxVal = dataPoints.reduce(math.max);
    double minVal = dataPoints.reduce(math.min);
    
    // Ensure some range for the chart
    maxVal = math.max(maxVal, 20.0);
    minVal = math.min(minVal, -20.0);
    final range = maxVal - minVal;

    final xStep = size.width / (dataPoints.length - 1);

    Offset getOffset(int i) {
      final normalizedY = (dataPoints[i] - minVal) / range;
      return Offset(i * xStep, size.height - (normalizedY * size.height));
    }

    // 1. Create the Path (Smooth Bezier)
    final path = Path();
    path.moveTo(getOffset(0).dx, getOffset(0).dy);

    for (int i = 0; i < dataPoints.length - 1; i++) {
      final p0 = getOffset(i);
      final p1 = getOffset(i + 1);
      final controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
      path.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, p1.dx, p1.dy);
    }

    // 2. Draw Gradient Fill
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withAlpha(80),
          color.withAlpha(0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // 3. Draw Grid Lines
    final gridPaint = Paint()
      ..color = Colors.white.withAlpha(15)
      ..strokeWidth = 0.5;
    
    for (int i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 4. Draw Center Line (0 cents)
    final zeroY = size.height - ((0.0 - minVal) / range * size.height);
    if (zeroY >= 0 && zeroY <= size.height) {
      final zeroPaint = Paint()
        ..color = parchment.withAlpha(40)
        ..strokeWidth = 1;
      
      double curX = 0;
      const dash = 4.0;
      const gap = 4.0;
      while (curX < size.width) {
        canvas.drawLine(Offset(curX, zeroY), Offset(curX + dash, zeroY), zeroPaint);
        curX += dash + gap;
      }
    }

    // 5. Draw Main Stroke
    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    canvas.drawPath(path, strokePaint);

    // 6. Draw Data Points with Glow
    final pointPaint = Paint()..color = Colors.white;
    final glowPaint = Paint()
      ..color = color.withAlpha(150)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    // Only draw points if there aren't too many to avoid clutter
    if (dataPoints.length < 50) {
      for (int i = 0; i < dataPoints.length; i++) {
        final pos = getOffset(i);
        canvas.drawCircle(pos, 4, glowPaint);
        canvas.drawCircle(pos, 2, pointPaint);
      }
    }
  }

  static const Color parchment = Color(0xFFCDD2BB);

  @override
  bool shouldRepaint(covariant _SmoothTrendPainter oldDelegate) => 
      oldDelegate.dataPoints != dataPoints || oldDelegate.color != color;
}
