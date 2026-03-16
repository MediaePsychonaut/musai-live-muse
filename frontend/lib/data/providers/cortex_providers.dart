import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/audio/audio_recorder.dart';
import '../../core/audio/audio_output_service.dart';
import '../../core/dsp/pitch_detector.dart';
import '../../core/secrets/secret_manager.dart';
import '../services/gemini_live_service.dart';
import 'mentor_providers.dart';
import 'engine_provider.dart';
import 'hardware_provider.dart';
import '../repositories/practice_ledger.dart';
import '../services/session_debrief_service.dart';
import '../services/lab_log_service.dart';

enum LiveStreamStatus { disconnected, connecting, connected, error }

class LiveStreamState {
  final LiveStreamStatus status;
  final String? error;
  final double volume; // 0.0 to 1.0Base
  final double pitch;
  final List<double> spectrum; // FFT Telemetry
  final double violinResonance;
  final double aiResonance;
  final double euteOutputAmplitude; // Native RMS
  final int pulseTick; // Oboe Native Downbeat
  final double centsDeviation; // Pitch Deviation
  final String noteName; // Pitch to Note mapping

  LiveStreamState({
    required this.status,
    this.error,
    this.volume = 0.0,
    this.pitch = 0.0,
    this.spectrum = const [],
    this.violinResonance = 0.0,
    this.aiResonance = 0.0,
    this.euteOutputAmplitude = 0.0,
    this.pulseTick = 0,
    this.centsDeviation = 0.0,
    this.noteName = "--",
  });

  LiveStreamState copyWith({
    LiveStreamStatus? status,
    String? error,
    double? volume,
    double? pitch,
    List<double>? spectrum,
    double? violinResonance,
    double? aiResonance,
    double? euteOutputAmplitude,
    int? pulseTick,
    double? centsDeviation,
    String? noteName,
  }) {
    return LiveStreamState(
      status: status ?? this.status,
      error: error ?? this.error,
      volume: volume ?? this.volume,
      pitch: pitch ?? this.pitch,
      spectrum: spectrum ?? this.spectrum,
      violinResonance: violinResonance ?? this.violinResonance,
      aiResonance: aiResonance ?? this.aiResonance,
      euteOutputAmplitude: euteOutputAmplitude ?? this.euteOutputAmplitude,
      pulseTick: pulseTick ?? this.pulseTick,
      centsDeviation: centsDeviation ?? this.centsDeviation,
      noteName: noteName ?? this.noteName,
    );
  }
}

class LiveStreamNotifier extends AsyncNotifier<LiveStreamState> {
  GeminiLiveService? _service;
  final _audioOutput = AudioOutputService();
  bool _connecting = false;

  @override
  FutureOr<LiveStreamState> build() {
    return LiveStreamState(status: LiveStreamStatus.disconnected);
  }

  Future<void> connect() async {
    if (_connecting) return;
    _connecting = true;

    final currentState = state.value ?? LiveStreamState(status: LiveStreamStatus.disconnected);
    state = AsyncValue.data(currentState.copyWith(status: LiveStreamStatus.connecting));

    try {
      final recorder = createRecorder();
      final apiKey = SecretManager().apiKey;
      await _audioOutput.init();
      
      final currentEngine = ref.read(engineProvider);
      final currentMentorData = ref.read(mentorProvider);
      final ledger = ref.read(practiceLedgerProvider);
      final summary = await ledger.getLastSessionSummary();
      final neuralRecall = await ledger.getMusicalPerformanceSummary();
      
      String extendedInstruction = currentMentorData.systemInstruction;
      if (summary != null) {
        final avgCents = summary['avg_cents'] as double;
        extendedInstruction += "\n\n<CONTEXT_PROTOCOL>\n";
        extendedInstruction += "TECHNICAL_HISTORY: User past session average deviation: ${avgCents.toStringAsFixed(2)} cents.\n";
        extendedInstruction += "$neuralRecall\n";
        extendedInstruction += avgCents > 15.0 
            ? "DIRECTIVE: THE USER EXHIBITED SIGNIFICANT PITCH DRIFT. PRIORITIZE TIGHT INTONATION FEEDBACK.\n"
            : "DIRECTIVE: THE USER WAS STABLE. FOCUS ON RHYTHMIC AND EXPRESSIVE TIMING.\n";
        extendedInstruction += "</CONTEXT_PROTOCOL>";
      }

      final primedMentor = MentorState(
        activeMentor: currentMentorData.activeMentor,
        name: currentMentorData.name,
        role: currentMentorData.role,
        primaryColor: currentMentorData.primaryColor,
        borderRadius: currentMentorData.borderRadius,
        voiceName: currentMentorData.voiceName,
        systemInstruction: extendedInstruction,
      );

      _service?.disconnect();
      _service = GeminiLiveService(apiKey, recorder, primedMentor, currentEngine);

      await _service!.connect(
        onMessage: (msg) {
          final audioChunk = msg['audio_chunk'];
          if (audioChunk != null && audioChunk is Uint8List) {
            _audioOutput.playChunk(audioChunk);
          }
        },
        onError: (err) {
          _connecting = false;
          state = AsyncValue.data(currentState.copyWith(
            status: LiveStreamStatus.error,
            error: "SYNC_FAIL: ${err.toString()}",
          ));
        },
        onDone: () {
          _connecting = false;
          disconnect();
        },
        onHardwareCommand: (name, args) {
          debugPrint("[DEBUG_COMMAND] Received: $name with args: $args");
          final hw = ref.read(hardwareProvider.notifier);
          final previousState = ref.read(hardwareProvider);
          debugPrint("[DEBUG_COMMAND] Pre-State: Metronome=${previousState.isMetronomeActive}, BPM=${previousState.bpm}, Drone=${previousState.isDroneActive}");
          
          hw.triggerAgencyPulse(); // GLOBAL PULSE ON AGENCY
          
          if (name == 'set_metronome') {
            final active = args['active'] ?? false;
            if (active) {
              final bpm = (args['bpm'] is num) ? (args['bpm'] as num).toInt() : 60;
              final signature = (args['signature'] is int) ? args['signature'] as int : 4;
              debugPrint("[DEBUG_COMMAND] Metronome Params: BPM=$bpm, Sig=$signature");
              hw.setBpm(bpm);
              hw.setSignature(signature); 
            }
            hw.setMetronome(active); 
            debugPrint("[DEBUG_COMMAND] Metronome Action: $active");
          } else if (name == 'set_drone') {
            final active = args['active'] ?? false;
            if (active) {
              double freq = (args['frequency'] is num) ? (args['frequency'] as num).toDouble() : 196.0;
              if (freq <= 0) freq = 196.0; 
              
              // [DIAG-63] Parse frequency to Note Name for HUD display
              final note = _mapFreqFromMidi(freq);
              
              // [PROTOCOL-ANCHOR-REPAIR] Direct frequency injection
              hw.setDrone(true, frequency: freq);
              hw.setKey(note);
              debugPrint("[DEBUG_COMMAND] Drone Action: $active, Freq=$freq ($note)");
            } else {
              hw.setDrone(false);
            }
          } else if (name == 'start_practice_session') {
            final nameArg = args['name'] ?? "Neural Rehearsal";
            final focusArg = args['focus'] ?? "General Mastery";
            ref.read(sessionObjectiveProvider.notifier).state = "$nameArg: $focusArg";
            ref.read(isSessionActiveProvider.notifier).state = true;
            ref.read(sessionTimerProvider.notifier).start(); 
            debugPrint("[DEBUG_COMMAND] Session Start: $nameArg");
          } else if (name == 'stop_practice_session') {
            ref.read(isSessionActiveProvider.notifier).state = false;
            ref.read(sessionTimerProvider.notifier).stop(); 
            debugPrint("[DEBUG_COMMAND] Session Stop");
          }
          
          final afterState = ref.read(hardwareProvider);
          debugPrint("[DEBUG_COMMAND] Post-State: Metronome=${afterState.isMetronomeActive}, BPM=${afterState.bpm}, Drone=${afterState.isDroneActive}");
        },
      );

      state = AsyncValue.data(currentState.copyWith(status: LiveStreamStatus.connected));
      _connecting = false;
    } catch (e) {
      _connecting = false;
      state = AsyncValue.data(currentState.copyWith(
        status: LiveStreamStatus.error,
        error: e.toString(),
      ));
    }
  }

  void disconnect() {
    _service?.disconnect();
    _service = null;
    _audioOutput.dispose();
    _connecting = false;
    
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncValue.data(currentState.copyWith(status: LiveStreamStatus.disconnected));
    }
  }
  
  void updateState(LiveStreamState newState) {
    state = AsyncValue.data(newState);
  }

  String _mapFreqFromMidi(double freq) {
    if (freq <= 0) return "--";
    double midi = 12 * (math.log(freq / 440.0) / math.ln2) + 69.0;
    int nearestMidi = midi.round();
    const notes = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];
    int octave = (nearestMidi ~/ 12) - 1;
    return "${notes[nearestMidi % 12]}$octave";
  }
}

class SensoryNotifier extends Notifier<void> {
  StreamSubscription? _audioSubscription;
  StreamSubscription? _telemetrySubscription;
  StreamSubscription? _pulseSubscription;
  PitchDetector? _pitchDetector;
  Timer? _stateThrottleTimer;
  final _practiceLedger = PracticeLedger();
  
  @override
  void build() {
    // Listen to both Session state and LiveStream status
    ref.listen<bool>(isSessionActiveProvider, (prev, isActive) => _syncSensoryState());
    ref.listen<AsyncValue<LiveStreamState>>(liveStreamStateProvider, (prev, status) => _syncSensoryState());
    ref.listen<bool>(tunerEnabledProvider, (prev, isTuner) => _syncSensoryState());
    ref.listen<HardwareState>(hardwareProvider, (prev, next) => _syncSensoryState());
    
    // Initial sync
    _syncSensoryState();
  }

  void _syncSensoryState() {
    final isSessionActive = ref.read(isSessionActiveProvider);
    final isTunerEnabled = ref.read(tunerEnabledProvider);
    final hardwareState = ref.read(hardwareProvider);
    final isMetronomeActive = hardwareState.isMetronomeActive;
    final isDroneActive = hardwareState.isDroneActive;
    final streamStatus = ref.read(liveStreamStateProvider).value?.status;
    final isAiConnected = streamStatus == LiveStreamStatus.connected;
    
    // PRIORITY: [MIC-SOVEREIGNTY] & [HARDWARE-SHIELD]
    // The microphone lifecycle and screen wakelock are strictly linked to active features.
    final bool isAnyFeatureActive = isSessionActive || isTunerEnabled || isAiConnected || isMetronomeActive || isDroneActive;
    
    if (isAnyFeatureActive) {
      _startSensoryLoop();
      WakelockPlus.enable(); // [HARDWARE-SHIELD-PERSISTENCE]
    } else {
      _stopSensoryLoop();
      WakelockPlus.disable(); // [HARDWARE-SHIELD-PERSISTENCE]
    }
  }

  Future<void> _startSensoryLoop() async {
    if (_pitchDetector != null) return;
    
    debugPrint("MUSE_LOG: [SENSORY] Activating Local Perception...");
    _pitchDetector = PitchDetector();
    
    final recorder = createRecorder();
    final hasPermission = await recorder.hasPermission();
    if (!hasPermission) {
      debugPrint("MUSE_LOG: [SENSORY] Permission Denied.");
      _pitchDetector = null;
      return;
    }

    await _pitchDetector!.init();
    await recorder.startStream(const CortexRecordConfig(sampleRate: 16000));
    
    double latestVolume = 0.0;
    double latestPitch = 0.0;
    double latestCents = 0.0;
    String latestNoteName = "--";
    List<double> latestSpectrum = [];
    double latestAiResonance = 0.0;

    _audioSubscription = recorder.audioStream.listen((frame) {
      _pitchDetector?.processFrame(frame, 16000);
      final ls = ref.read(liveStreamStateProvider.notifier);
      final service = ls._service;
      if (service != null && service.isConnected) {
         service.sendAudioFrame(frame);
      }
    });

    _pitchDetector!.results.listen((res) {
      latestVolume = res.volume;
      latestPitch = res.pitch;
      latestCents = res.centsDeviation;
      latestSpectrum = res.spectrum;
      latestNoteName = res.noteName;
    });

    _telemetrySubscription = AudioOutputService().telemetryStream.listen((rms) {
      latestAiResonance = rms;
    });

    _pulseSubscription = AudioOutputService().pulseStream.listen((tick) {
       final notifier = ref.read(liveStreamStateProvider.notifier);
       final currentState = ref.read(liveStreamStateProvider).value;
       if (currentState != null) {
         notifier.updateState(currentState.copyWith(pulseTick: currentState.pulseTick + 1));
       }
    });

    _stateThrottleTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      final notifier = ref.read(liveStreamStateProvider.notifier);
      final currentState = ref.read(liveStreamStateProvider).value;
      if (currentState != null) {
        final activeSessionId = ref.read(sessionManagerProvider);
        if (activeSessionId != null && latestVolume > 0.002) {
           _practiceLedger.logTelemetry(activeSessionId, latestPitch, latestCents);
           
           // [MUSICAL-VAULT] High-fidelity event persistence
           final noteName = latestNoteName;
           _practiceLedger.logMusicalSequence(
             activeSessionId, 
             noteName, 
             latestPitch, 
             latestCents, 
             latestVolume
           );
        }

        if (latestVolume > 0.05) {
           LabLogService().log("AUDIO_PEAK", "RMS_SPIKE", metadata: "RMS: ${latestVolume.toStringAsFixed(3)}");
         }

        final service = notifier._service; 
        
        notifier.updateState(currentState.copyWith(
          volume: latestVolume,
          pitch: latestVolume > 0.002 ? latestPitch : 0.0,
          spectrum: latestSpectrum,
          violinResonance: service?.lastResonance ?? 0.0,
          aiResonance: latestAiResonance,
          euteOutputAmplitude: service?.lastEuteAmplitude ?? 0.0,
          centsDeviation: (latestVolume > 0.002) ? latestCents : 0.0,
          noteName: (latestVolume > 0.002) ? latestNoteName : "--",
        ));
      }
    });
  }

  void _stopSensoryLoop() {
    _audioSubscription?.cancel();
    _telemetrySubscription?.cancel();
    _pulseSubscription?.cancel();
    _stateThrottleTimer?.cancel();
    _pitchDetector?.dispose();
    _pitchDetector = null;
    debugPrint("MUSE_LOG: [SENSORY] Local Perception Offline.");
  }
}

final sensoryProvider = NotifierProvider<SensoryNotifier, void>(() => SensoryNotifier());

final liveStreamStateProvider = AsyncNotifierProvider<LiveStreamNotifier, LiveStreamState>(() {
  return LiveStreamNotifier();
});

// --- Progress Vault Providers ---

final practiceLedgerProvider = Provider((ref) => PracticeLedger());

final practiceUpdateTriggerProvider = StateProvider<int>((ref) => 0);

final progressStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  ref.watch(practiceUpdateTriggerProvider); // Watch for new sessions
  final ledger = ref.watch(practiceLedgerProvider);
  return await ledger.getProgressStats();
});

final recentTelemetryProvider = FutureProvider<List<double>>((ref) async {
  ref.watch(practiceUpdateTriggerProvider); // Watch for new sessions
  final ledger = ref.watch(practiceLedgerProvider);
  return await ledger.getRecentSessionTelemetry();
});

final sessionDebriefProvider = FutureProvider<String?>((ref) async {
  ref.watch(practiceUpdateTriggerProvider);
  final summary = await ref.watch(practiceLedgerProvider).getLastSessionSummary();
  if (summary == null) return null;
  
  final debriefService = SessionDebriefService();
  return await debriefService.generateDebrief(summary);
});

// --- UI / Session Logic ---

final tunerEnabledProvider = StateProvider<bool>((ref) => false);

class SessionTimerNotifier extends StateNotifier<Duration> {
  Timer? _timer;
  DateTime? _startTime;

  SessionTimerNotifier() : super(Duration.zero);

  void start() {
    state = Duration.zero; // INITIAL RESET TO PREVENT GHOSTING
    _startTime = DateTime.now();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      state = DateTime.now().difference(_startTime!);
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    state = Duration.zero;
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final sessionTimerProvider = StateNotifierProvider<SessionTimerNotifier, Duration>((ref) {
  return SessionTimerNotifier();
});

final sessionObjectiveProvider = StateProvider<String?>((ref) => null);
final isSessionActiveProvider = StateProvider<bool>((ref) => false);

class SessionManagerNotifier extends StateNotifier<int?> {
  final PracticeLedger _ledger;
  final Ref ref;

  SessionManagerNotifier(this._ledger, this.ref) : super(null) {
    // 1. Listen to Session Toggle
    ref.listen<bool>(isSessionActiveProvider, (prev, isActive) async {
      if (isActive && state == null) {
        final objective = ref.read(sessionObjectiveProvider) ?? "ACTIVE FLOW";
        final engine = ref.read(engineProvider).toString().split('.').last;
        state = await _ledger.startSession(engineVersion: engine, objective: objective);
      } else if (!isActive && state != null) {
        await _closeCurrentSession();
      }
    });

    // 2. [LIFECYCLE_INTEGRITY] Auto-closure on Mentor Switch
    ref.listen(mentorProvider, (prev, next) async {
      if (state != null) {
        debugPrint("MUSE_LOG: [LIFECYCLE] Mentor identity shift detected. Closing current session.");
        await _closeCurrentSession();
      }
    });
  }

  Future<void> _closeCurrentSession() async {
    if (state != null) {
      await _ledger.endSession(state!);
      state = null;
      ref.read(practiceUpdateTriggerProvider.notifier).state++;
      ref.read(isSessionActiveProvider.notifier).state = false;
    }
  }
}

final sessionManagerProvider = StateNotifierProvider<SessionManagerNotifier, int?>((ref) {
  return SessionManagerNotifier(ref.watch(practiceLedgerProvider), ref);
});
