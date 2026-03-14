import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/musai_theme.dart';
import '../../../../data/providers/cortex_providers.dart';
import '../widgets/soul_state_visualizer.dart';

class SanctuaryHudScreen extends ConsumerWidget {
  const SanctuaryHudScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveStream = ref.watch(liveStreamStateProvider);
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
          // Background Atmospheric Element (Subtle Gradient)
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.5,
                  colors: [
                    MusaiTheme.neonCyan.withAlpha(13), // 0.05 * 255
                    MusaiTheme.obsidianaBlack,
                  ],
              ),
            ),
          ),
          
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Status Readout
                  Text(
                    statusText,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          letterSpacing: 8,
                          shadows: const [
                            Shadow(
                              color: MusaiTheme.neonCyan,
                              blurRadius: 10,
                            ),
                          ],
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
                          color: MusaiTheme.neonCyan.withAlpha(51), // 0.2 * 255
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
                        backgroundColor: MusaiTheme.deepGrey,
                        foregroundColor: status == LiveStreamStatus.connected 
                            ? MusaiTheme.neonCyan 
                            : MusaiTheme.neonCyan.withAlpha(153), // 0.6 * 255
                        padding: const EdgeInsets.all(24),
                        side: BorderSide(
                          color: MusaiTheme.neonCyan.withAlpha(128), // 0.5 * 255
                          width: 1,
                        ),
                      ),
                    ),
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
