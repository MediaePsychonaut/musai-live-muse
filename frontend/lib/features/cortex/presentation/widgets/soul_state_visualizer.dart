import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/musai_theme.dart';
import '../../../../data/providers/cortex_providers.dart';
import '../../../../data/providers/mentor_providers.dart';

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
    final mentorState = ref.watch(mentorProvider);
    
    final volume = liveStream.value?.volume ?? 0.0;
    final spectrum = liveStream.value?.spectrum ?? const [];
    final resonance = liveStream.value?.violinResonance ?? 0.0;
    final status = liveStream.value?.status ?? LiveStreamStatus.disconnected;
    final isLive = status == LiveStreamStatus.connected;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(400, 200),
          painter: _WavePainter(
            progress: _controller.value,
            volume: volume,
            spectrum: spectrum,
            resonance: resonance,
            mentorColor: mentorState.primaryColor,
            resonanceColor: MusaiTheme.deepSpaceTeal,
            isLive: isLive,
          ),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  final double progress;
  final double volume;
  final List<double> spectrum;
  final double resonance;
  final Color mentorColor;
  final Color resonanceColor;
  final bool isLive;

  _WavePainter({
    required this.progress, 
    required this.volume,
    required this.spectrum,
    required this.resonance,
    required this.mentorColor,
    required this.resonanceColor,
    required this.isLive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = mentorColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final centerY = size.height / 2;

    // 1. DEEP SPACE RESONANCE (BLOOM ANCHOR)
    if (isLive) {
      final bloomPaint = Paint()
        ..color = resonanceColor.withAlpha((resonance * 180).clamp(0, 255).toInt())
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 15 + (resonance * 30));
      
      canvas.drawCircle(Offset(size.width / 2, centerY), 40 + (resonance * 60), bloomPaint);
    }

    // 2. SPECTRAL RESONANCE (FFT BARS)
    if (isLive && spectrum.isNotEmpty) {
      final barPaint = Paint()
        ..color = mentorColor.withAlpha(51) // 0.2 opacity
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
        
      final barCount = math.min(spectrum.length, 64);
      final barWidth = size.width / barCount;
      
      for (int i = 0; i < barCount; i++) {
        final magnitude = spectrum[i] * 120.0; // Scale for visibility
        final x = i * barWidth;
        
        canvas.drawLine(
          Offset(x, centerY - (magnitude / 2)),
          Offset(x, centerY + (magnitude / 2)),
          barPaint,
        );
      }
    }

    // 3. SOUL VIBRATION (THE WAVE)
    final path = Path();
    for (double x = 0; x <= size.width; x++) {
      final normalizedX = x / size.width;
      
      // PHYSICS LOCK: High-Fidelity Vibration Engine
      final baseAmplitude = isLive ? 15.0 : 4.0;
      final surge = volume * 55.0;
      final resonanceMod = resonance * 35.0;
      
      // Complex modulation from spectrum
      double fftModulation = 0.0;
      if (isLive && spectrum.isNotEmpty) {
        final fftIndex = (normalizedX * 10).toInt() % spectrum.length;
        fftModulation = spectrum[fftIndex] * 25.0;
      }
      
      final amplitude = baseAmplitude + surge + resonanceMod + fftModulation;
      
      final baseFrequency = isLive ? 2.5 : 1.2;
      final frequency = baseFrequency + (volume * 2.0) + (resonance * 1.5);

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
      // RESONANCE GLOW: Intensifies with volume + resonance
      canvas.drawPath(
        path,
        paint..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 + (volume * 10) + (resonance * 8)),
      );
    }
    
    // CORE TECHNICAL LINE
    canvas.drawPath(
      path,
      paint..maskFilter = null..color = mentorColor,
    );
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.progress != progress || 
      oldDelegate.isLive != isLive || 
      oldDelegate.volume != volume ||
      oldDelegate.resonance != resonance ||
      oldDelegate.spectrum != spectrum ||
      oldDelegate.mentorColor != mentorColor;
}
