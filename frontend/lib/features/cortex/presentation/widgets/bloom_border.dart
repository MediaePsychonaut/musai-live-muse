import 'package:flutter/material.dart';

class BloomBorder extends StatefulWidget {
  final Widget child;
  final Color bloomColor;
  final double borderRadius;
  final double strokeWidth;
  final double blurRadius;
  final int pulseTick; // Injected from cortex provider
  final bool isCircle;

  const BloomBorder({
    super.key,
    required this.child,
    required this.bloomColor,
    required this.pulseTick,
    this.borderRadius = 8.0,
    this.strokeWidth = 1.0,
    this.blurRadius = 4.0,
    this.isCircle = false,
  });

  @override
  State<BloomBorder> createState() => _BloomBorderState();
}

class _BloomBorderState extends State<BloomBorder> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _decayAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
       vsync: this,
       duration: const Duration(milliseconds: 400),
    );

    // Easing curve: Starts strong and fades out
    _decayAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCirc),
    );
  }

  @override
  void didUpdateWidget(covariant BloomBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulseTick != oldWidget.pulseTick) {
      // Fire the rhythmic decay!
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _decayAnimation,
      builder: (context, child) {
        // Compute active properties based on physical decay
        final activeBlur = widget.blurRadius + (_decayAnimation.value * 12.0); // Spike bloom
        final activeAlpha = 50 + (_decayAnimation.value * 200).toInt(); // 50 to 250 opacity

        return CustomPaint(
          painter: _BloomPainter(
            color: widget.bloomColor.withAlpha(activeAlpha),
            radius: widget.borderRadius,
            strokeWidth: widget.strokeWidth + (_decayAnimation.value * 2.0), // Slight stroke thickening
            blurRadius: activeBlur,
            isCircle: widget.isCircle,
          ),
          child: widget.child,
        );
      },
    );
  }
}

class _BloomPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;
  final double blurRadius;
  final bool isCircle;

  _BloomPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.blurRadius,
    this.isCircle = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    
    // 1. Draw the Bloom (Glow)
    final glowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurRadius);
    
    if (isCircle) {
      canvas.drawCircle(size.center(Offset.zero), size.width / 2, glowPaint);
    } else {
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
      canvas.drawRRect(rrect, glowPaint);
    }

    // 2. Draw the Sharp 1px Border (Opaque core)
    final strokePaint = Paint()
      ..color = color.withAlpha(255) // Keep core solid
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2; 
    
    if (isCircle) {
      canvas.drawCircle(size.center(Offset.zero), size.width / 2, strokePaint);
    } else {
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
      canvas.drawRRect(rrect, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BloomPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.blurRadius != blurRadius;
  }
}
