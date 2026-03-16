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
    final aiResonance = liveStream.value?.aiResonance ?? 0.0;
    final euteAmplitude = liveStream.value?.euteOutputAmplitude ?? 0.0;
    final status = liveStream.value?.status ?? LiveStreamStatus.disconnected;
    final isTunerActive = ref.watch(tunerEnabledProvider);
    final isLive = status == LiveStreamStatus.connected || isTunerActive;

    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _WavePainter(
                progress: _controller.value,
                volume: volume,
                spectrum: spectrum,
                resonance: resonance,
                aiResonance: aiResonance,
                euteOutputAmplitude: euteAmplitude,
                mentorColor: mentorState.primaryColor,
                resonanceColor: MusaiTheme.deepSpaceTeal,
                isLive: isLive,
              ),
            );
          },
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
  final double aiResonance;
  final double euteOutputAmplitude;
  final Color mentorColor;
  final Color resonanceColor;
  final bool isLive;

  _WavePainter({
    required this.progress, 
    required this.volume,
    required this.spectrum,
    required this.resonance,
    required this.aiResonance,
    required this.euteOutputAmplitude,
    required this.mentorColor,
    required this.resonanceColor,
    required this.isLive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final isActuallyActive = isLive && (volume > 0.005);

    // 1. DEEP SPACE RESONANCE (ALPHA GLOW ANCHOR)
    if (isActuallyActive) {
      final effectiveResonance = math.max(resonance, volume * 0.8);
      
      final bloomPaint = Paint()
        ..color = mentorColor.withAlpha((effectiveResonance * 150).clamp(0, 180).toInt())
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 20 + (effectiveResonance * 60));
      
      canvas.drawCircle(Offset(size.width / 2, centerY), 60 + (effectiveResonance * 120), bloomPaint);
    }

    // 2. SPECTRAL HARMONY (FFT BARS - FULL LUMINANCE)
    if (isActuallyActive && spectrum.isNotEmpty) {
      final barPaint = Paint()
        ..color = mentorColor.withAlpha(80) 
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
        
      final barCount = math.min(spectrum.length, 120); // Fewer bars, more impact
      final barWidth = size.width / barCount;
      
      for (int i = 0; i < barCount; i++) {
        final magnitude = spectrum[i] * 400.0 * (1.0 + resonance); // Aggressive scaling
        final x = i * barWidth;
        
        canvas.drawLine(
          Offset(x, centerY - (magnitude / 2)),
          Offset(x, centerY + (magnitude / 2)),
          barPaint,
        );
      }
    }

    // 3. SOUL VIBRATION (THE CRAZY OSCILLOSCOPE)
    final path = Path();
    final wavePaint = Paint()
      ..color = mentorColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    for (double x = 0; x <= size.width; x += 2) {
      final normalizedX = x / size.width;
      
      // Multi-Sine Layering for "Crazy" motion
      final baseAmplitude = isActuallyActive ? 40.0 : 8.0;
      final audioSurge = volume * 180.0;
      final resonanceMod = resonance * 60.0;
      
      // Secondary harmonic
      final secondaryWave = math.sin((normalizedX * 12.0 + progress * 5.0) * math.pi) * (audioSurge * 0.3);
      
      final amplitude = baseAmplitude + audioSurge + resonanceMod + secondaryWave;
      final frequency = 2.0 + (volume * 4.0) + (resonance * 2.0);

      // Envelope: Taper ends to prevent flickering on screen edges
      final envelope = math.sin(normalizedX * math.pi);
      
      final y = centerY + 
          math.sin((normalizedX * frequency + progress * 2.5) * 2 * math.pi) * amplitude * envelope;
          
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    if (isActuallyActive) {
      // Glow Layer for the Sine Wave
      canvas.drawPath(
        path,
        wavePaint..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 + (volume * 15)),
      );
    }
    
    // Solid Core
    canvas.drawPath(
      path,
      wavePaint..maskFilter = null..color = mentorColor,
    );
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.progress != progress || 
      oldDelegate.isLive != isLive || 
      oldDelegate.volume != volume ||
      oldDelegate.resonance != resonance ||
      oldDelegate.aiResonance != aiResonance ||
      oldDelegate.euteOutputAmplitude != euteOutputAmplitude ||
      oldDelegate.spectrum != spectrum ||
      oldDelegate.mentorColor != mentorColor;
}
