import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/musai_theme.dart';
import '../../../../data/providers/cortex_providers.dart';
import '../../../../data/providers/mentor_providers.dart';
import '../widgets/soul_state_visualizer.dart';
import '../widgets/bloom_border.dart';
import '../../../../data/providers/hardware_provider.dart';
import '../widgets/progress_view.dart';
import '../../../../core/dsp/pitch_matrix.dart';
import '../widgets/agency_indicator.dart';
import '../widgets/mentor_button.dart';
import '../widgets/agency_pulse_overlay.dart';

class SanctuaryHudScreen extends ConsumerStatefulWidget {
  const SanctuaryHudScreen({super.key});

  @override
  ConsumerState<SanctuaryHudScreen> createState() => _SanctuaryHudScreenState();
}

class _SanctuaryHudScreenState extends ConsumerState<SanctuaryHudScreen> {
  bool _isVaultView = false;

  @override
  Widget build(BuildContext context) {
    final liveStream = ref.watch(liveStreamStateProvider);
    final mentorState = ref.watch(mentorProvider);
    final hardwareState = ref.watch(hardwareProvider);
    final isTunerActive = ref.watch(tunerEnabledProvider);
    final isSessionActive = ref.watch(isSessionActiveProvider);
    final sessionDuration = ref.watch(sessionTimerProvider);
    ref.watch(sensoryProvider); 
    final status = liveStream.value?.status ?? LiveStreamStatus.disconnected;

    String statusText = "MUSE: MEDITATING";
    switch (status) {
      case LiveStreamStatus.connecting: statusText = "MUSE: SYNCHRONIZING..."; break;
      case LiveStreamStatus.connected: statusText = "MUSE: LIVE"; break;
      case LiveStreamStatus.error: statusText = "MUSE: OFFLINE"; break;
      case LiveStreamStatus.disconnected: statusText = "MUSE: MEDITATING"; break;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. STABLE BACKGROUND (GRADIENT ANCHOR)
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black,
                    MusaiTheme.deepSpaceTeal.withAlpha(50), 
                    MusaiTheme.deepSpaceTeal.withAlpha(120),
                  ],
                  stops: const [0.5, 0.8, 1.0],
                ),
              ),
            ),
          ),
          
          // 2. THE LUMINOUS WAVE (CONTEXT-AWARE)
          IgnorePointer(
            child: SoulStateVisualizer(isVaultView: _isVaultView),
          ),
          
          // 3. CINEMATIC OVERLAY SYSTEM (TRANSITIONS)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            layoutBuilder: (child, previousChildren) {
              return Stack(
                alignment: Alignment.center,
                children: [
                   ...previousChildren,
                   if (child != null) child,
                ],
              );
            },
            transitionBuilder: (child, animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (context, _) {
                  final blurValue = (1.0 - animation.value) * 15.0;
                  return ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: blurValue, sigmaY: blurValue),
                    child: FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                  );
                },
              );
            },
            child: KeyedSubtree(
              key: ValueKey(mentorState.name), 
              child: SafeArea(
                child: PageView(
                  onPageChanged: (index) {
                    setState(() {
                      _isVaultView = index == 1;
                    });
                  },
                  children: [
                    // PAGE 1: THE SANCTUARY HUD
                    SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 40, bottom: 40),
                        child: OrientationBuilder(
                          builder: (context, orientation) {
                            final isLandscape = orientation == Orientation.landscape;
                            
                            final indicatorsAndIdentity = isLandscape
                                ? Container(
                                    height: 100, // [STABILIZATION] Robust header height
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center, // [ALIGMENT-ZENITH] Final baseline lock
                                      children: [
                                        // LEFT ANCHOR (Metronome)
                                        Expanded(
                                          flex: 1,
                                          child: Align(
                                            alignment: Alignment.centerRight,
                                            child: Padding(
                                              padding: const EdgeInsets.only(right: 32),
                                              child: _buildMetronomeIndicator(context, ref, hardwareState, mentorState),
                                            ),
                                          ),
                                        ),
                                        // CENTER ANCHOR (Identity)
                                        Expanded(
                                          flex: 2,
                                          child: Center(
                                            child: _buildMentorIdentity(context, mentorState),
                                          ),
                                        ),
                                        // RIGHT ANCHOR (Drone)
                                        Expanded(
                                          flex: 1,
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Padding(
                                              padding: const EdgeInsets.only(left: 32),
                                              child: _buildDroneIndicator(context, ref, hardwareState, mentorState),
                                            ),
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
                                      const SizedBox(height: 4),
                                      _buildMentorIdentity(context, mentorState),
                                    ],
                                  );

                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                indicatorsAndIdentity,
                                const SizedBox(height: 40),
                                
                                // Tuner Output (Priority Display) [UI-SOVEREIGN-CANDY]
                                if (isTunerActive)
                                  OrientationBuilder(
                                    builder: (context, orientation) {
                                      final bool isLandscape = orientation == Orientation.landscape;
                                      final double tunerScale = isLandscape ? 1.35 : 1.0;
                                      return Center(
                                        child: SizedBox(
                                          width: 350,
                                          height: 350,
                                          child: Transform.scale(
                                            scale: tunerScale,
                                            child: RepaintBoundary(
                                              child: Column(
                                                children: [
                                                  // Visual Deviation Gauge
                                                  _TunerGauge(
                                                    cents: liveStream.value?.centsDeviation ?? 0.0,
                                                    primaryColor: mentorState.primaryColor,
                                                    secondaryColor: mentorState.secondaryColor,
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Text(
                                                    "${liveStream.value?.pitch.toStringAsFixed(1) ?? "0.0"} Hz / DEVIATION: ${liveStream.value?.centsDeviation.toStringAsFixed(1) ?? "--"} CENTS",
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: mentorState.primaryColor.withAlpha(180),
                                                      letterSpacing: 2.0,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 20),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  ),

                                // CENTRAL RESONANCE HUB (Status indicator)
                                Container(
                                  height: 80,
                                  alignment: Alignment.center,
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 300),
                                    opacity: status == LiveStreamStatus.connected ? 1.0 : 0.4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: mentorState.primaryColor.withAlpha(80)),
                                        borderRadius: BorderRadius.circular(4),
                                        boxShadow: [
                                          BoxShadow(
                                            color: mentorState.primaryColor.withAlpha(status == LiveStreamStatus.connected ? 40 : 15),
                                            blurRadius: status == LiveStreamStatus.connected ? 30 : 15,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        statusText,
                                        style: TextStyle(
                                          color: mentorState.primaryColor,
                                          letterSpacing: 4,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w300,
                                          shadows: status != LiveStreamStatus.connected ? [
                                             Shadow(color: mentorState.primaryColor.withAlpha(150), blurRadius: 20)
                                          ] : null,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // SESSION STATUS
                                if (isSessionActive)
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(height: 20),
                                      Text(
                                        _formatDuration(sessionDuration),
                                        style: TextStyle(
                                          color: MusaiTheme.parchment.withAlpha(240),
                                          letterSpacing: 2,
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        "SESSION TIME",
                                        style: TextStyle(
                                          color: MusaiTheme.parchment.withAlpha(120),
                                          letterSpacing: 4,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w300,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        "OBJECTIVE",
                                        style: TextStyle(
                                          color: mentorState.primaryColor.withAlpha(150),
                                          letterSpacing: 3,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w300,
                                        ),
                                      ),
                                      Text(
                                        (ref.watch(sessionObjectiveProvider) ?? "ACTIVE FLOW").toUpperCase(),
                                        style: TextStyle(
                                          color: mentorState.primaryColor,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.5,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                
                                const SizedBox(height: 50),
                                
                                // MIC ACTUATOR (CIRCULAR SOVEREIGNTY)
                                GestureDetector(
                                  onTap: () {
                                    final notifier = ref.read(liveStreamStateProvider.notifier);
                                    if (status == LiveStreamStatus.connected) {
                                      notifier.disconnect();
                                    } else {
                                      notifier.connect();
                                    }
                                  },
                                  child: BloomBorder(
                                    bloomColor: mentorState.primaryColor,
                                    pulseTick: liveStream.value?.pulseTick ?? 0,
                                    isCircle: true,
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      width: 90,
                                      height: 90,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSessionActive 
                                            ? mentorState.primaryColor.withValues(alpha: 0.15) 
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: isSessionActive 
                                              ? mentorState.primaryColor 
                                              : mentorState.primaryColor.withValues(alpha: 0.3),
                                          width: 2.0,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.mic_none_rounded,
                                        size: 48,
                                        color: isSessionActive ? mentorState.primaryColor : Colors.white24,
                                      ),
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(height: 60),
                                
                                // SESSION CONTROLS
                                if (!isSessionActive)
                                  SizedBox(
                                    width: 220,
                                    height: 50,
                                    child: OutlinedButton(
                                      onPressed: () => _showSessionStartModal(context, ref),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(color: mentorState.primaryColor.withAlpha(100)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                                      ),
                                      child: const Text("START SESSION", style: TextStyle(letterSpacing: 3, color: Colors.white70)),
                                    ),
                                  )
                                else
                                  OutlinedButton(
                                    onPressed: () {
                                      ref.read(isSessionActiveProvider.notifier).state = false;
                                      ref.read(sessionTimerProvider.notifier).stop();
                                    },
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: MusaiTheme.vitalRed, width: 2),
                                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                                      shape: const RoundedRectangleBorder(),
                                    ),
                                    child: const Text(
                                      "COMPLETE SESSION",
                                      style: TextStyle(
                                        fontSize: 14, 
                                        fontWeight: FontWeight.bold, 
                                        letterSpacing: 4, 
                                        color: MusaiTheme.vitalRed
                                      ),
                                    ),
                                  ),

                                const SizedBox(height: 80),
                                
                                // MENTOR SELECTOR
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    MentorButton(mentor: Mentor.eute, label: "EUTE"),
                                    SizedBox(width: 12),
                                    MentorButton(mentor: Mentor.saravi, label: "SARAVÍ"),
                                    SizedBox(width: 12),
                                    MentorButton(mentor: Mentor.orfio, label: "ORFIO"),
                                  ],
                                ),
                                
                                const SizedBox(height: 40),
                                
                                Text(
                                  "SWIPE LEFT FOR PROGRESS VAULT",
                                  style: TextStyle(
                                    color: MusaiTheme.parchment.withAlpha(80),
                                    fontSize: 9,
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
            ),
          ),
          
          // 4. AGENCY PULSE LAYER
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
      mainAxisAlignment: MainAxisAlignment.center, // [ALIGMENT-ZENITH] Vertical centering
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
                      const SizedBox(width: 8),
                      // [PREMIUM-CONTROLS] Stepped BPM Layout
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildStepButton(Icons.remove, () {
                            ref.read(hardwareProvider.notifier).setBpm((hw.bpm - 1).clamp(30, 300));
                          }, mentorState.primaryColor),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 60,
                            child: TextField(
                              onSubmitted: (val) {
                                final newBpm = int.tryParse(val);
                                if (newBpm != null) {
                                  ref.read(hardwareProvider.notifier).setBpm(newBpm.clamp(30, 300));
                                }
                              },
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                hintText: "${hw.bpm}",
                                hintStyle: const TextStyle(color: Colors.white),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: mentorState.primaryColor.withAlpha(80))),
                                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: mentorState.primaryColor)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildStepButton(Icons.add, () {
                            ref.read(hardwareProvider.notifier).setBpm((hw.bpm + 1).clamp(30, 300));
                          }, mentorState.primaryColor),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text("TIME SIGNATURE", style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 2)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [2, 3, 4, 6].map((sig) {
                      final isActive = hw.signature == sig;
                      return InkWell(
                        onTap: () => ref.read(hardwareProvider.notifier).setSignature(sig),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: isActive ? mentorState.primaryColor : Colors.white10),
                            color: isActive ? mentorState.primaryColor.withAlpha(50) : null,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text("$sig/4", style: TextStyle(color: isActive ? Colors.white : Colors.white24, fontWeight: FontWeight.bold)),
                        ),
                      );
                    }).toList(),
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
                      child: const Text("TAP TEMPO", style: TextStyle(letterSpacing: 4, color: Colors.white)),
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

  Widget _buildStepButton(IconData icon, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          border: Border.all(color: color.withAlpha(100)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

class _TunerGauge extends ConsumerWidget {
  final double cents;
  final Color primaryColor;
  final Color secondaryColor;

  const _TunerGauge({
    required this.cents, 
    required this.primaryColor, 
    required this.secondaryColor
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveStream = ref.watch(liveStreamStateProvider).value;
    final noteName = liveStream?.noteName ?? "--";
    
    return Column(
      children: [
        SizedBox(
          width: 360,
          height: 80, // Slightly taller for evolved symbols
          child: CustomPaint(
            painter: _GaugePainter(
              cents: cents, 
              secondaryColor: secondaryColor, 
              primaryColor: primaryColor,
              noteName: noteName
            ),
          ),
        ),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double cents; // -50 to +50
  final Color secondaryColor;
  final Color primaryColor;
  final String noteName;

  _GaugePainter({
    required this.cents, 
    required this.secondaryColor, 
    required this.primaryColor,
    required this.noteName
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final centerX = size.width / 2;
    
    // Background Line
    final bgPaint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    
    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), bgPaint);
    
    // Ticks
    final tickPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.0;
    
    for (int i = -5; i <= 5; i++) {
        final x = centerX + (i * size.width / 10);
        final height = (i == 0) ? 12.0 : 6.0;
        canvas.drawLine(Offset(x, centerY - height/2), Offset(x, centerY + height/2), tickPaint);
    }
    
    // Indicator (Linear Displacement)
    final clampedCents = cents.clamp(-50.0, 50.0);
    final indicatorX = centerX + (clampedCents * size.width / 100);
    
    // [UI-CONTRAST-ZENITH] Shift to Secondary Color for Tuner precision
    final glowColor = (cents.abs() < 5) ? secondaryColor : Colors.white.withValues(alpha: 0.8);
    
    final indicatorPaint = Paint()
      ..color = glowColor
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    
    // Draw Glow
    canvas.drawCircle(Offset(indicatorX, centerY), 6.0, indicatorPaint);
    
    // Draw Sharp Needle [HARDENED-INDICATOR]
    final needleGlowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9) // Increased glow ring
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0)
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    final needlePaint = Paint()
      ..color = primaryColor // [CONTRAST-ZENITH] Primary colored needle
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    
    // Draw Needle Glow First
    canvas.drawLine(
      Offset(indicatorX, centerY - 20),
      Offset(indicatorX, centerY + 20),
      needleGlowPaint,
    );

    // Draw Needle
    canvas.drawLine(
      Offset(indicatorX, centerY - 20),
      Offset(indicatorX, centerY + 20),
      needlePaint,
    );

    // [SINGLE-LABEL-SYSTEM] Unified Dynamic Luminance
    if (noteName != "--") {
       final absCents = cents.abs();
       
       // [CONTEXTUAL-LUMINANCE-ZENITH]
       // 0.4 opacity when cents >= 15
       // 0.9 opacity when cents < 15
       // 1.0 + primary color shadow when cents < 5
       final double opacity = absCents < 15 ? 0.9 : 0.4;
       
       // [LOCK-IN-GLOW-ZENITH] 
       final bool isLocked = absCents < 5;
       final baseLabelColor = isLocked ? secondaryColor : Colors.white;
       final finalOpacity = isLocked ? 1.0 : opacity;
       
       final symbolStyle = TextStyle(
         color: Colors.white.withValues(alpha: 0.45), // Reduced fade for symbols v2
         fontSize: 24, // Optimized for 36pt main label
         fontWeight: FontWeight.w400,
         letterSpacing: 1
       );
       
       final mainNoteStyle = TextStyle(
         color: baseLabelColor.withValues(alpha: finalOpacity), 
         fontSize: 36, // Main central label zenith
         fontWeight: FontWeight.bold, 
         letterSpacing: 2,
         shadows: isLocked ? [
           Shadow(color: secondaryColor.withValues(alpha: 0.9), blurRadius: 30), // HARDENED GLOW [TERMINUS-UI]
           Shadow(color: secondaryColor.withValues(alpha: 0.7), blurRadius: 45),
         ] : null,
       );
       
       // Center Note (The One Label to Rule Them All)
       _drawCenteredText(canvas, noteName, Offset(centerX, centerY - 45), mainNoteStyle);
       
       // [SYMBOL-EVOLUTION] High-elevation accidentals
       _drawCenteredText(canvas, "♭", Offset(0, centerY - 45), symbolStyle);
       _drawCenteredText(canvas, "♯", Offset(size.width, centerY - 45), symbolStyle);
    }
  }

  void _drawCenteredText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset - Offset(tp.width / 2, tp.height / 2));
  }
 
  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) => 
      oldDelegate.cents != cents || 
      oldDelegate.noteName != noteName ||
      oldDelegate.secondaryColor != secondaryColor ||
      oldDelegate.primaryColor != primaryColor;
}
