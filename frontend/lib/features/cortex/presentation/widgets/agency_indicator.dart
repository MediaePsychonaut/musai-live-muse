import 'package:flutter/material.dart';
import 'dart:math' as math;

class AgencyIndicator extends StatefulWidget {
  final String label;
  final bool isActive;
  final String description;
  final Color color;

  const AgencyIndicator({
    super.key,
    required this.label,
    required this.isActive,
    required this.description,
    required this.color,
  });

  @override
  State<AgencyIndicator> createState() => _AgencyIndicatorState();
}

class _AgencyIndicatorState extends State<AgencyIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Outer Rotating Ring (Celestial Wireframe)
            if (widget.isActive)
              RotationTransition(
                turns: _controller,
                child: CustomPaint(
                  size: const Size(48, 48),
                  painter: _WireframeRingPainter(color: widget.color.withAlpha(100)),
                ),
              ),
            
            // Central Core
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isActive ? widget.color.withAlpha(40) : Colors.transparent,
                border: Border.all(
                  color: widget.color.withAlpha(widget.isActive ? 255 : 50),
                  width: 1.5,
                ),
                boxShadow: widget.isActive ? [
                  BoxShadow(
                    color: widget.color.withAlpha(150),
                    blurRadius: 15,
                    spreadRadius: 2,
                  )
                ] : null,
              ),
              child: widget.isActive 
                ? Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.color,
                      ),
                    ),
                  )
                : null,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 12,
            color: widget.color.withAlpha(widget.isActive ? 255 : 100),
            fontWeight: widget.isActive ? FontWeight.bold : FontWeight.normal,
            letterSpacing: 2.0,
            fontFamily: 'SpaceMono',
          ),
        ),
        if (widget.isActive)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              widget.description,
              style: TextStyle(
                fontSize: 24,
                color: widget.color,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                fontFamily: 'SpaceMono',
              ),
            ),
          ),
      ],
    );
  }
}

class _WireframeRingPainter extends CustomPainter {
  final Color color;
  _WireframeRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw a series of dashed arcs or lines to create a wireframe feel
    const segments = 12;
    const angleStep = (2 * math.pi) / segments;

    for (int i = 0; i < segments; i++) {
      final startAngle = i * angleStep;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        angleStep * 0.4,
        false,
        paint,
      );
      
      // Add a small outward "tick"
      final tickStart = Offset(
        center.dx + math.cos(startAngle) * radius,
        center.dy + math.sin(startAngle) * radius,
      );
      final tickEnd = Offset(
        center.dx + math.cos(startAngle) * (radius + 4),
        center.dy + math.sin(startAngle) * (radius + 4),
      );
      canvas.drawLine(tickStart, tickEnd, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
