import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/musai_theme.dart';
import '../../../../data/providers/cortex_providers.dart';
import '../../../../data/providers/mentor_providers.dart';

class SoulStateVisualizer extends ConsumerStatefulWidget {
  final bool isVaultView;
  const SoulStateVisualizer({super.key, this.isVaultView = false});

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
                isVaultView: widget.isVaultView,
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
  final bool isVaultView;

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
    required this.isVaultView,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final isActuallyActive = isLive && (volume > 0.005);
    final baseOpacity = isVaultView ? 0.05 : 1.0;

    // 1. SPECTRAL AURA (FFT BARS - HIGH DENSITY & GAPLESS [SPECTRAL_DENSITY])
    if (isActuallyActive && spectrum.isNotEmpty) {
      final barCount = math.min(spectrum.length, 256); // [GAPLESS_DENSITY]
      final barWidth = size.width / barCount;
      final maxHeight = size.height * 0.45;
      
      final barPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = mentorColor.withOpacity(0.25 * baseOpacity); 
        
      for (int i = 0; i < barCount; i++) {
        // [MAGNITUDE_CONSTRAINTS]
        final val = (i < spectrum.length) ? spectrum[i] : 0.0;
        final mag = math.min(val * 500.0 * (1.0 + resonance * 1.5), maxHeight);
        final x = i * barWidth;
        
        // Draw centered bars with subtle overlap for gapless feel
        canvas.drawRect(
          Rect.fromLTRB(x, centerY - mag/2, x + barWidth + 0.2, centerY + mag/2),
          barPaint,
        );
      }
    }

    // 2. DEEP SPACE RESONANCE (BLOOM ANCHOR)
    if (isActuallyActive && !isVaultView) {
      final effectiveResonance = math.max(resonance, volume * 1.2);
      
      final bloomPaint = Paint()
        ..color = mentorColor.withAlpha((effectiveResonance * 100).clamp(0, 140).toInt())
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 40 + (effectiveResonance * 100));
      
      canvas.drawCircle(Offset(size.width / 2, centerY), 90 + (effectiveResonance * 160), bloomPaint);
    }

    // 3. THE CRAZY OSCILLOSCOPE (TRIPLE-LAYER NEON [CRAZY_WAVE])
    final path = Path();
    final random = math.Random(42); // Deterministic jitter
    
    for (double x = 0; x <= size.width; x += 1.5) {
      final normalizedX = x / size.width;
      
      final baseAmplitude = isActuallyActive ? 50.0 : 10.0;
      final audioSurge = volume * 350.0;
      
      // Triple-sine Synthesis with Jitter
      final freq = 2.0 + (volume * 8.0) + (resonance * 10.0);
      final phase = progress * 6.0;
      final jitter = isActuallyActive ? (random.nextDouble() - 0.5) * 15.0 * volume : 0.0;
      
      final wave1 = math.sin((normalizedX * freq + phase) * 2 * math.pi);
      final wave2 = math.sin((normalizedX * freq * 2.3 + phase * 1.8) * 2 * math.pi) * 0.4;
      final wave3 = math.sin((normalizedX * freq * 0.7 + phase * 0.9) * 2 * math.pi) * 0.3;
      
      final resonanceBoost = 1.2 + (resonance * 1.5);
      final amplitude = (baseAmplitude + audioSurge) * resonanceBoost * baseOpacity;
      final envelope = math.sin(normalizedX * math.pi); // Taper edges
      
      final y = centerY + (wave1 + wave2 + wave3) * amplitude * envelope + jitter;
          
      if (x == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }

    if (isActuallyActive) {
      // NEON LAYER 1: OUTER SPECTRAL BLOOM
      canvas.drawPath(path, Paint()
        ..color = mentorColor.withOpacity(0.2 * baseOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22.0));

      // NEON LAYER 2: VIBRANT HALO
      canvas.drawPath(path, Paint()
        ..color = mentorColor.withOpacity(0.5 * baseOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0));

      // NEON LAYER 3: PHOTONIC CORE
      canvas.drawPath(path, Paint()
        ..color = Colors.white.withOpacity(0.8 * baseOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0));
    }
    
    // SOLID RADIANT ANCHOR
    canvas.drawPath(path, Paint()
      ..color = isActuallyActive ? mentorColor : mentorColor.withAlpha(50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) =>
      oldDelegate.progress != progress || 
      oldDelegate.isLive != isLive || 
      oldDelegate.volume != volume ||
      oldDelegate.resonance != resonance ||
      oldDelegate.aiResonance != aiResonance ||
      oldDelegate.euteOutputAmplitude != euteOutputAmplitude ||
      oldDelegate.spectrum != spectrum ||
      oldDelegate.isVaultView != isVaultView ||
      oldDelegate.mentorColor != mentorColor;
}
