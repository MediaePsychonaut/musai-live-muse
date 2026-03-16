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
import '../widgets/agency_indicator.dart';
import '../widgets/engine_toggle.dart';
import '../widgets/mentor_button.dart';
import '../widgets/agency_pulse_overlay.dart';


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
    ref.watch(sensoryProvider); // Activate persistent sensory loop
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
                    padding: const EdgeInsets.only(top: 40, bottom: 20), // Heightened anchor
                    child: OrientationBuilder(
                      builder: (context, orientation) {
                        final isLandscape = orientation == Orientation.landscape;
                        
                        // 1. TOP CONTROL & IDENTITY GROUP
                        final indicatorsAndIdentity = isLandscape
                            ? Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: _buildMetronomeIndicator(context, ref, hardwareState, mentorState),
                                      ),
                                    ),
                                    _buildMentorIdentity(context, mentorState),
                                    Expanded(
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: _buildDroneIndicator(context, ref, hardwareState, mentorState),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 30),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        _buildMetronomeIndicator(context, ref, hardwareState, mentorState),
                                        _buildDroneIndicator(context, ref, hardwareState, mentorState),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4), // TACTILE PERFECTION (MISSION: GEOMETRY-FINALE)
                                  _buildMentorIdentity(context, mentorState),
                                ],
                              );

                        return Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            indicatorsAndIdentity,
                            const SizedBox(height: 30),
                            
                            // ENGINE SWITCHER (MISSION: DYNAMIC-INJECTION)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                EngineToggle(
                                  label: "GEN 2.0 (v1α)",
                                  isActive: engineType == EngineType.flash20Exp,
                                  onTap: () => ref.read(engineProvider.notifier).switchEngine(EngineType.flash20Exp),
                                  color: mentorState.primaryColor,
                                ),
                                const SizedBox(width: 12),
                                EngineToggle(
                                  label: "GEN 2.5 (v1β)",
                                  isActive: engineType == EngineType.flash25Native,
                                  onTap: () => ref.read(engineProvider.notifier).switchEngine(EngineType.flash25Native),
                                  color: mentorState.primaryColor,
                                ),
                                const SizedBox(width: 12),
                                EngineToggle(
                                  label: "TUNER",
                                  isActive: isTunerActive,
                                  onTap: () => ref.read(tunerEnabledProvider.notifier).state = !isTunerActive,
                                  color: Colors.white70,
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 40),

                            // 3. STATUS & BLOOM
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
                            
                            // 4. SOUL STATE (VISUALIZER)
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
                            
                            // 5. CONTROL HUB
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: mentorState.primaryColor.withAlpha(51),
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
                                      : mentorState.primaryColor.withAlpha(153),
                                  padding: const EdgeInsets.all(24),
                                  side: BorderSide(
                                    color: mentorState.primaryColor.withAlpha(128),
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 40),

                            // 6. SESSION HUB
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
                                  Column(
                                    children: [
                                      Text(
                                        "SESSION TARGET",
                                        style: TextStyle(
                                          color: mentorState.primaryColor.withAlpha(80),
                                          fontSize: 9,
                                          letterSpacing: 3,
                                          fontFamily: 'SpaceMono',
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 800),
                                        transitionBuilder: (child, animation) {
                                          return FadeTransition(
                                            opacity: animation,
                                            child: ScaleTransition(
                                              scale: Tween<double>(begin: 0.95, end: 1.0).animate(CurvedAnimation(
                                                parent: animation,
                                                curve: Curves.elasticOut,
                                              )),
                                              child: child,
                                            ),
                                          );
                                        },
                                        child: Container(
                                          key: ValueKey(ref.watch(sessionObjectiveProvider)),
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                                          decoration: BoxDecoration(
                                            border: Border.symmetric(
                                              horizontal: BorderSide(color: mentorState.primaryColor.withAlpha(30), width: 0.5),
                                            ),
                                          ),
                                          child: Text(
                                            (ref.watch(sessionObjectiveProvider) ?? "ACTIVE FLOW").toUpperCase(),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.white.withAlpha(200),
                                              fontSize: 14,
                                              letterSpacing: 2.5,
                                              fontFamily: 'Montserrat',
                                              fontWeight: FontWeight.w700,
                                              shadows: [
                                                Shadow(
                                                  color: mentorState.primaryColor.withAlpha(150),
                                                  blurRadius: 10,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  TextButton(
                                    onPressed: () {
                                      ref.read(isSessionActiveProvider.notifier).state = false;
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.white38,
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      side: const BorderSide(color: Colors.white12),
                                      shape: const RoundedRectangleBorder(),
                                    ),
                                    child: const Text(
                                      "COMPLETE SESSION",
                                      style: TextStyle(fontSize: 10, letterSpacing: 4),
                                    ),
                                  ),
                                ],
                              ),

                            const SizedBox(height: 40),
                            
                            // 7. MENTOR SELECTOR
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                MentorButton(mentor: Mentor.eute, label: "EUTE"),
                                SizedBox(width: 8),
                                MentorButton(mentor: Mentor.saravi, label: "SARAVÍ"),
                                SizedBox(width: 8),
                                MentorButton(mentor: Mentor.orfio, label: "ORFIO"),
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
                        );
                      },
                    ),
                  ),
                ),
                
                // PAGE 2: PROGRESS VAULT
                const ProgressView(),
              ],
            ),
          ),
          
          // AI AGENCY BLOOM (MISSION: AGENCY-RESONANCE)
          const AgencyPulseOverlay(),
        ],
      ),
    );
  }

  Widget _buildMetronomeIndicator(BuildContext context, WidgetRef ref, HardwareState hardwareState, MentorState mentorState) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showMetronomeModal(context, ref),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: AgencyIndicator(
          label: "METRONOME",
          isActive: hardwareState.isMetronomeActive,
          description: "${hardwareState.bpm} BPM",
          color: mentorState.primaryColor,
        ),
      ),
    );
  }

  Widget _buildDroneIndicator(BuildContext context, WidgetRef ref, HardwareState hardwareState, MentorState mentorState) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showDroneModal(context, ref),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: AgencyIndicator(
          label: "DRONE",
          isActive: hardwareState.isDroneActive,
          description: "KEY: ${hardwareState.key}",
          color: mentorState.primaryColor,
        ),
      ),
    );
  }

  Widget _buildMentorIdentity(BuildContext context, MentorState mentorState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          mentorState.name,
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            color: mentorState.primaryColor,
            fontSize: 48,
          ),
        ),
        Text(
          mentorState.role,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            letterSpacing: 6,
            color: MusaiTheme.parchment.withAlpha(128),
            fontSize: 14,
          ),
        ),
      ],
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
            final mentorState = ref.watch(mentorProvider);
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
                        activeTrackColor: mentorState.primaryColor.withAlpha(100),
                        activeThumbColor: mentorState.primaryColor,
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
                          activeColor: mentorState.primaryColor,
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
                        side: BorderSide(color: mentorState.primaryColor.withAlpha(100)),
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
            final mentorState = ref.watch(mentorProvider);
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
                        activeTrackColor: mentorState.primaryColor.withAlpha(100),
                        activeThumbColor: mentorState.primaryColor,
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
                              border: Border.all(color: isActive ? mentorState.primaryColor : Colors.white10),
                              color: isActive ? mentorState.primaryColor.withAlpha(50) : null,
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

// Modular components moved to separate files
