import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/providers/hardware_provider.dart';
import '../../../../data/providers/mentor_providers.dart';

class AgencyPulseOverlay extends ConsumerStatefulWidget {
  const AgencyPulseOverlay({super.key});

  @override
  ConsumerState<AgencyPulseOverlay> createState() => _AgencyPulseOverlayState();
}

class _AgencyPulseOverlayState extends ConsumerState<AgencyPulseOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  DateTime? _lastTrigger;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.4).chain(CurveTween(curve: Curves.easeOut)), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.4, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 80),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerPulse() {
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    // Watch the hardware state for pulse triggers
    final hardwareState = ref.watch(hardwareProvider);
    final mentorState = ref.watch(mentorProvider);

    if (hardwareState.lastAgencyCommandTimestamp != null &&
        hardwareState.lastAgencyCommandTimestamp != _lastTrigger) {
      _lastTrigger = hardwareState.lastAgencyCommandTimestamp;
      WidgetsBinding.instance.addPostFrameCallback((_) => _triggerPulse());
    }

    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _opacityAnimation,
          builder: (context, child) {
            if (_opacityAnimation.value <= 0) return const SizedBox.shrink();
            return Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    mentorState.primaryColor.withValues(alpha: _opacityAnimation.value),
                    mentorState.primaryColor.withValues(alpha: 0.0),
                  ],
                  radius: 1.5,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
