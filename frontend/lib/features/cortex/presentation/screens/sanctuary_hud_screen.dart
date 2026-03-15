import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/musai_theme.dart';
import '../../../../data/providers/cortex_providers.dart';
import '../../../../data/providers/mentor_providers.dart';
import '../widgets/soul_state_visualizer.dart';
import '../widgets/bloom_border.dart';
import '../../../../data/providers/engine_provider.dart';
import '../../../../data/providers/hardware_provider.dart';
import '../widgets/progress_view.dart';
import '../../../../core/dsp/pitch_matrix.dart';


class SanctuaryHudScreen extends ConsumerWidget {
  const SanctuaryHudScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveStream = ref.watch(liveStreamStateProvider);
    final mentorState = ref.watch(mentorProvider);
    final engineType = ref.watch(engineProvider);
    final hardwareState = ref.watch(hardwareProvider);
    final isTunerActive = ref.watch(tunerEnabledProvider);
    final isSessionActive = ref.watch(isSessionActiveProvider);
    final sessionDuration = ref.watch(sessionTimerProvider);
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
            child: PageView(
              children: [
                // PAGE 1: THE SANCTUARY HUD
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // AGENCY INDICATORS (MISSION 4)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 30),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: () => _showMetronomeModal(context, ref),
                                child: _AgencyIndicator(
                                  label: "METRONOME",
                                  isActive: hardwareState.isMetronomeActive,
                                  description: "${hardwareState.bpm} BPM",
                                  color: mentorState.primaryColor,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _showDroneModal(context, ref),
                                child: _AgencyIndicator(
                                  label: "DRONE",
                                  isActive: hardwareState.isDroneActive,
                                  description: "KEY: ${hardwareState.key}",
                                  color: mentorState.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 30),
                        
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
                    
                    const SizedBox(height: 30),
  
                    // ENGINE SWITCHER (MISSION: DYNAMIC-INJECTION)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _EngineToggle(
                          label: "GEN 2.0 (v1α)",
                          isActive: engineType == EngineType.flash20Exp,
                          onTap: () => ref.read(engineProvider.notifier).switchEngine(EngineType.flash20Exp),
                          color: mentorState.primaryColor,
                        ),
                        const SizedBox(width: 12),
                        _EngineToggle(
                          label: "GEN 2.5 (v1β)",
                          isActive: engineType == EngineType.flash25Native,
                          onTap: () => ref.read(engineProvider.notifier).switchEngine(EngineType.flash25Native),
                          color: mentorState.primaryColor,
                        ),
                        const SizedBox(width: 12),
                        _EngineToggle(
                          label: "TUNER",
                          isActive: isTunerActive,
                          onTap: () => ref.read(tunerEnabledProvider.notifier).state = !isTunerActive,
                          color: Colors.white70,
                        ),
                      ],
                    ),
  
                    
                    const SizedBox(height: 40),
  
                    // Status Readout with Bloom Engine
                    RepaintBoundary(
                      child: BloomBorder(
                        bloomColor: mentorState.primaryColor,
                        borderRadius: mentorState.borderRadius,
                        pulseTick: liveStream.value?.pulseTick ?? 0,
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
                    ),
                    
                    const SizedBox(height: 50),
                    
                    // State of Soul (Visualizer)
                    RepaintBoundary(
                      child: Column(
                        children: [
                          if (isTunerActive) ...[
                            Text(
                              "${liveStream.value?.pitch.toStringAsFixed(1) ?? "0.0"} Hz",
                              style: TextStyle(
                                color: MusaiTheme.parchment.withAlpha(200),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                            Text(
                              "${(liveStream.value?.volume ?? 0) > 0.05 ? (liveStream.value?.pitch.toStringAsFixed(1) ?? "--") : "--"} Hz / deviation: ${(liveStream.value?.volume ?? 0) > 0.05 ? (liveStream.value?.centsDeviation.toStringAsFixed(1) ?? "--") : "--"} cents",
                              style: TextStyle(
                                fontSize: 10,
                                color: (liveStream.value?.volume ?? 0) > 0.05 ? mentorState.primaryColor : Colors.white24,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          const SoulStateVisualizer(),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 60),
                    
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
  
                        // SESSION HUB (MISSION 7)
                        if (!isSessionActive)
                          OutlinedButton(
                            onPressed: () => _showSessionStartModal(context, ref),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: mentorState.primaryColor,
                              side: BorderSide(color: mentorState.primaryColor.withAlpha(100)),
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            ),
                            child: const Text("START SESSION", style: TextStyle(letterSpacing: 2)),
                          )
                        else
                          Column(
                            children: [
                              Text(
                                _formatDuration(sessionDuration),
                                style: TextStyle(
                                  color: mentorState.primaryColor,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 4,
                                  fontFamily: 'RobotoMono',
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                ref.watch(sessionObjectiveProvider) ?? "ACTIVE FLOW",
                                style: TextStyle(
                                  color: mentorState.primaryColor.withAlpha(150),
                                  fontSize: 10,
                                  letterSpacing: 2,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  ref.read(isSessionActiveProvider.notifier).state = false;
                                  ref.read(sessionTimerProvider.notifier).stop();
                                },
                                child: Text(
                                  "END SESSION",
                                  style: TextStyle(color: Colors.red.withAlpha(150), fontSize: 10),
                                ),
                              ),
                            ],
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
                        
                        const SizedBox(height: 30),
                        
                        Text(
                          "SWIPE LEFT FOR PROGRESS",
                          style: TextStyle(
                            color: MusaiTheme.parchment.withAlpha(50),
                            fontSize: 8,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // PAGE 2: PROGRESS VAULT (SCAFFOLD)
                const ProgressView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  void _showMetronomeModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: MusaiTheme.sovereignBlack,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final hw = ref.watch(hardwareProvider);
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("METRONOME", style: TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 2)),
                      Switch(
                        value: hw.isMetronomeActive,
                        onChanged: (val) => ref.read(hardwareProvider.notifier).setMetronome(val),
                        activeTrackColor: MusaiTheme.deepSpaceTeal.withAlpha(100),
                        activeThumbColor: MusaiTheme.deepSpaceTeal,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Text("BPM", style: TextStyle(color: Colors.white70)),
                      Expanded(
                        child: Slider(
                          value: hw.bpm.toDouble(),
                          min: 30,
                          max: 300,
                          onChanged: (val) => ref.read(hardwareProvider.notifier).setBpm(val.toInt()),
                          activeColor: MusaiTheme.deepSpaceTeal,
                        ),
                      ),
                      Text("${hw.bpm}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 80,
                    child: OutlinedButton(
                      onPressed: () => ref.read(hardwareProvider.notifier).tapTempo(),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: MusaiTheme.deepSpaceTeal.withAlpha(100)),
                      ),
                      child: const Text("TAP TEMPO", style: TextStyle(letterSpacing: 4)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDroneModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: MusaiTheme.sovereignBlack,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final hw = ref.watch(hardwareProvider);
            final notes = PitchMatrix.a440Frequencies.keys.toList();
            
            return Container(
              padding: const EdgeInsets.all(24),
              height: 400,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("DRONE", style: TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 2)),
                      Switch(
                        value: hw.isDroneActive,
                        onChanged: (val) => ref.read(hardwareProvider.notifier).setDrone(val),
                        activeTrackColor: MusaiTheme.deepSpaceTeal.withAlpha(100),
                        activeThumbColor: MusaiTheme.deepSpaceTeal,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text("SELECT KEY", style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 2)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        childAspectRatio: 1,
                      ),
                      itemCount: notes.length,
                      itemBuilder: (context, index) {
                        final note = notes[index];
                        final isActive = hw.key == note;
                        return InkWell(
                          onTap: () => ref.read(hardwareProvider.notifier).setKey(note),
                          child: Container(
                            alignment: Alignment.center,
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              border: Border.all(color: isActive ? MusaiTheme.deepSpaceTeal : Colors.white10),
                              color: isActive ? MusaiTheme.deepSpaceTeal.withAlpha(50) : null,
                            ),
                            child: Text(
                              note,
                              style: TextStyle(
                                fontSize: 10,
                                color: isActive ? Colors.white : Colors.white38,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSessionStartModal(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MusaiTheme.sovereignBlack,
        title: const Text("SESSION OBJECTIVE", style: TextStyle(color: Colors.white, letterSpacing: 2)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Enter objective...",
            hintStyle: TextStyle(color: Colors.white24),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
          TextButton(
            onPressed: () {
              ref.read(sessionObjectiveProvider.notifier).state = controller.text.isNotEmpty ? controller.text : "ACTIVE FLOW";
              ref.read(isSessionActiveProvider.notifier).state = true;
              ref.read(sessionTimerProvider.notifier).start();
              Navigator.pop(context);
            },
            child: const Text("ASCEND"),
          ),
        ],
      ),
    );
  }
}

class _EngineToggle extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color color;

  const _EngineToggle({
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isActive ? color : color.withAlpha(50),
            width: 1,
          ),
          color: isActive ? color.withAlpha(30) : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? color : color.withAlpha(100),
            fontSize: 10,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            letterSpacing: 1.2,
          ),
        ),
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
      onPressed: () {
        ref.read(liveStreamStateProvider.notifier).disconnect();
        ref.read(mentorProvider.notifier).switchMentor(mentor);
      },
      style: TextButton.styleFrom(
        foregroundColor: isActive ? Colors.white : Colors.white38,
        backgroundColor: isActive ? MusaiTheme.deepSpaceTeal.withAlpha(128) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Image.asset(
         'assets/icons/${mentor.name}_icon.png', 
         width: 24, height: 24, 
         errorBuilder: (c, e, s) => Text(
           label,
           style: TextStyle(
             color: isActive ? Colors.white : Colors.white30,
             fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
             letterSpacing: 2,
             fontSize: 12,
           ),
         ),
      ),
    );
  }
}

class _AgencyIndicator extends StatelessWidget {
  final String label;
  final bool isActive;
  final String description;
  final Color color;

  const _AgencyIndicator({
    required this.label,
    required this.isActive,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          width: 12, // Increased from 8
          height: 12, // Increased from 8
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? color : Colors.transparent,
            border: Border.all(color: color.withAlpha(isActive ? 255 : 50)),
            boxShadow: isActive ? [
              BoxShadow(
                color: color.withAlpha(200),
                blurRadius: 15, // Increased
                spreadRadius: 3, // Increased
              )
            ] : null,
          ),
        ),
        const SizedBox(height: 8), // Increased
        Text(
          label,
          style: TextStyle(
            fontSize: 10, // Increased from 8
            color: color.withAlpha(isActive ? 255 : 100),
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            letterSpacing: 1.5,
          ),
        ),
        if (isActive)
          Text(
            description,
            style: TextStyle(
              fontSize: 8, // Increased from 6
              color: color.withAlpha(150),
              letterSpacing: 1.0,
            ),
          ),
      ],
    );
  }
}
