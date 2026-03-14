import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/musai_theme.dart';
import '../../../../data/providers/cortex_providers.dart';

class SoulStateVisualizer extends ConsumerStatefulWidget {
  const SoulStateVisualizer({super.key});

  @override
  ConsumerState<SoulStateVisualizer> createState() => _SoulStateVisualizerState();
}

class _SoulStateVisualizerState extends ConsumerState<SoulStateVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final liveStream = ref.watch(liveStreamStateProvider);
    final status = liveStream.value?.status ?? LiveStreamStatus.disconnected;
    final volume = liveStream.value?.volume ?? 0.0;
    final isLive = status == LiveStreamStatus.connected;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(300, 150),
          painter: _WavePainter(
            progress: _controller.value,
            color: isLive ? MusaiTheme.neonCyan : MusaiTheme.neonCyan.withAlpha(51),
            isLive: isLive,
            volume: volume,
          ),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isLive;
  final double volume;

  _WavePainter({
    required this.progress, 
    required this.color,
    required this.isLive,
    required this.volume,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final centerY = size.height / 2;
    
    for (double x = 0; x <= size.width; x++) {
      final normalizedX = x / size.width;
      
      // PHYSICS LOCK: High-Fidelity Vibration Engine
      // Base amplitude + Volume Surge
      final baseAmplitude = isLive ? 15.0 : 4.0;
      final surge = volume * 55.0;
      final amplitude = baseAmplitude + surge;
      
      // DYNAMIC FREQUENCY: Complex resonance as volume increases
      final baseFrequency = isLive ? 2.5 : 1.2;
      final frequency = baseFrequency + (volume * 2.5);

      // EDGE DAMPING: Premium horizontal fade-out
      final damping = math.sin(normalizedX * math.pi);
      
      final y = centerY + 
          math.sin((normalizedX * frequency + progress) * 2 * math.pi) * amplitude * damping;
          
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    if (isLive) {
      // RESONANCE GLOW: Intensifies with volume
      canvas.drawPath(
        path,
        paint..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 + (volume * 12)),
      );
    }
    
    // CORE TECHNICAL LINE
    canvas.drawPath(
      path,
      paint..maskFilter = null..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.progress != progress || 
      oldDelegate.isLive != isLive || 
      oldDelegate.volume != volume;
}
