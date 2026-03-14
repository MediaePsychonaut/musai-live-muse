import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/musai_theme.dart';
import '../../../../data/providers/cortex_providers.dart';
import '../../../../data/providers/mentor_providers.dart';
import '../widgets/soul_state_visualizer.dart';
import '../widgets/bloom_border.dart';

class SanctuaryHudScreen extends ConsumerWidget {
  const SanctuaryHudScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveStream = ref.watch(liveStreamStateProvider);
    final mentorState = ref.watch(mentorProvider);
    final status = liveStream.value?.status ?? LiveStreamStatus.disconnected;

    String statusText = "MUSE: MEDITATING";
    switch (status) {
      case LiveStreamStatus.connecting:
        statusText = "MUSE: SYNCHRONIZING...";
        break;
      case LiveStreamStatus.connected:
        statusText = "MUSE: LIVE";
        break;
      case LiveStreamStatus.error:
        statusText = "MUSE: OFFLINE (CHECK KEY)";
        break;
      case LiveStreamStatus.disconnected:
        statusText = "MUSE: MEDITATING";
        break;
    }

    return Scaffold(
      body: Stack(
        children: [
          // Background: Deep Space Anchor Gradient (V2.0)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black,
                  MusaiTheme.deepSpaceTeal,
                ],
                stops: [0.85, 1.0], // Teal at bottom with 15% visibility
              ),
            ),
          ),
          
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // MENTOR IDENTITY
                  Text(
                    mentorState.name,
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: mentorState.primaryColor,
                    ),
                  ),
                  Text(
                    mentorState.role,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      letterSpacing: 4,
                      color: MusaiTheme.parchment.withAlpha(128),
                    ),
                  ),
                  
                  const SizedBox(height: 40),

                  // Status Readout with Bloom Engine
                  BloomBorder(
                    bloomColor: mentorState.primaryColor,
                    borderRadius: mentorState.borderRadius,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Text(
                        statusText,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              letterSpacing: 8,
                              color: mentorState.primaryColor,
                              shadows: [
                                Shadow(
                                  color: mentorState.primaryColor,
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 60),
                  
                  // State of Soul (Visualizer)
                  const SoulStateVisualizer(),
                  
                  const SizedBox(height: 80),
                  
                  // Control Hub (Microphone)
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: mentorState.primaryColor.withAlpha(51), // 0.2 * 255
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: IconButton(
                      iconSize: 48,
                      icon: Icon(
                        status == LiveStreamStatus.connected 
                            ? Icons.mic_rounded 
                            : Icons.mic_none_rounded,
                      ),
                      onPressed: () {
                        final notifier = ref.read(liveStreamStateProvider.notifier);
                        if (status == LiveStreamStatus.connected) {
                          notifier.disconnect();
                        } else {
                          notifier.connect();
                        }
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: MusaiTheme.sovereignBlack,
                        foregroundColor: status == LiveStreamStatus.connected 
                            ? mentorState.primaryColor 
                            : mentorState.primaryColor.withAlpha(153), // 0.6 * 255
                        padding: const EdgeInsets.all(24),
                        side: BorderSide(
                          color: mentorState.primaryColor.withAlpha(128), // 0.5 * 255
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _MentorButton(Mentor.eute, "EUTE"),
                      SizedBox(width: 8),
                      _MentorButton(Mentor.saravi, "SARAVÍ"),
                      SizedBox(width: 8),
                      _MentorButton(Mentor.orfio, "ORFIO"),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MentorButton extends ConsumerWidget {
  final Mentor mentor;
  final String label;

  const _MentorButton(this.mentor, this.label);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeMentor = ref.watch(mentorProvider).activeMentor;
    final isActive = activeMentor == mentor;
    
    return TextButton(
      onPressed: () => ref.read(mentorProvider.notifier).switchMentor(mentor),
      style: TextButton.styleFrom(
        foregroundColor: isActive ? Colors.white : Colors.white38,
        backgroundColor: isActive ? MusaiTheme.deepSpaceTeal.withAlpha(128) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Text(label),
    );
  }
}
