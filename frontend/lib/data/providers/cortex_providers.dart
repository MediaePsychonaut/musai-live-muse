import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    );
  }
}

class LiveStreamNotifier extends AsyncNotifier<LiveStreamState> {
  GeminiLiveService? _service;
  StreamSubscription? _audioSubscription;
  PitchDetector? _pitchDetector;
  StreamSubscription? _pitchSubscription;
  StreamSubscription? _telemetrySubscription;
  StreamSubscription? _pulseSubscription;
  Timer? _stateThrottleTimer;
  final _audioOutput = AudioOutputService();
  bool _connecting = false;
  
  final PracticeLedger _practiceLedger = PracticeLedger();
  int? _activeSessionId;

  @override
  FutureOr<LiveStreamState> build() {
    return LiveStreamState(status: LiveStreamStatus.disconnected);
  }

  Future<void> connect() async {
    if (_connecting) return;
    _connecting = true;

    state = AsyncValue.data(LiveStreamState(status: LiveStreamStatus.connecting));

    try {
      final recorder = createRecorder();
      
      final hasPermission = await recorder.hasPermission();
      if (!hasPermission) {
        _connecting = false;
        state = AsyncValue.data(LiveStreamState(
          status: LiveStreamStatus.error,
          error: "PERMISSION_DENIED: Microphone access is required.",
        ));
        return;
      }

      final apiKey = SecretManager().apiKey;
      
      // Initialize SoLoud for Output
      await _audioOutput.init();
      
      final currentEngine = ref.read(engineProvider);
      final currentEngineName = currentEngine.toString().split('.').last;

      _activeSessionId = await _practiceLedger.startSession(currentEngineName);
      final summary = await _practiceLedger.getLastSessionSummary();
      final currentMentorData = ref.read(mentorProvider);
      
      String extendedInstruction = currentMentorData.systemInstruction;
      if (summary != null) {
        final avgCents = summary['avg_cents'] as double;
        extendedInstruction += "\n\n<CONTEXT_PROTOCOL>\n";
        extendedInstruction += "USER PAST SESSION AVERAGE DEVIATION: ${avgCents.toStringAsFixed(2)} CENTS.\n";
        if (avgCents > 15.0) {
           extendedInstruction += "DIRECTIVE: THE USER EXHIBITED SIGNIFICANT PITCH DRIFT IN THE LAST SESSION. PRIORITIZE TIGHT INTONATION FEEDBACK.\n";
        } else {
           extendedInstruction += "DIRECTIVE: THE USER WAS INTONATIONALLY STABLE IN THE LAST SESSION. FOCUS ON RHYTHMIC AND EXPRESSIVE TIMING.\n";
        }
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
          // 1. Handle Audio Chunks (24kHz PCM) - [MISSION: GAPLESS]
          final audioChunk = msg['audio_chunk'];
          if (audioChunk != null && audioChunk is Uint8List) {
            // Push directly to native sink for zero-stutter gapless playback
            _audioOutput.playChunk(audioChunk);
          }

          // 2. Process technical feedback from EUTE
          final serverContent = msg['server_content'] ?? msg['serverContent'];
          if (serverContent != null) {
            final modelTurn = serverContent['model_turn'] ?? serverContent['modelTurn'];
            if (modelTurn != null) {
              final parts = modelTurn['parts'] as List?;
              if (parts != null) {
                for (final part in parts) {
                  final text = part['text'];
                  if (text != null) {
                    debugPrint("MUSE_LOG: [EUTE] Response: $text");
                  }
                }
              }
            }
          }
        },
        onError: (err) {
          _connecting = false;
          state = AsyncValue.data(LiveStreamState(
            status: LiveStreamStatus.error,
            error: "SYNC_FAIL: ${err.toString()}",
          ));
        },
        onDone: () {
          _connecting = false;
          disconnect();
        },
        onHardwareCommand: (name, args) {
          final hw = ref.read(hardwareProvider.notifier);
          if (name == 'set_metronome') {
            final bool active = args['active'] ?? false;
            hw.setMetronome(active);
            if (active) {
              final bpm = (args['bpm'] is num) ? (args['bpm'] as num).toInt() : 60;
              hw.setBpm(bpm);
            }
          } else if (name == 'set_drone') {
            final bool active = args['active'] ?? false;
            hw.setDrone(active);
            if (active) {
              final freq = (args['frequency'] is num) ? (args['frequency'] as num).toDouble() : 440.0;
              // Map frequency back to Key for UI display if needed, or just show freq
              hw.setKey("${freq.toStringAsFixed(0)}Hz");
            }
          }
        },
      );

      // [SEQUENTIAL-HANDSHAKE] Setup is strictly complete. Activate Audio Pipeline.
      debugPrint("MUSE_LOG: [EUTE] Protocol Synchronized. Activating Audio Pipeline...");

      // Unified Governor State (Memory Buffer)
      PitchDetectorResult? latestPitchResult;
      double latestAiResonance = 0.0;
      double latestEuteAmplitude = 0.0;

      // Initialize Pitch Detector Isolate
      _pitchDetector = PitchDetector();
      await _pitchDetector!.init();
      
      _pitchSubscription = _pitchDetector!.results.listen((result) {
        latestPitchResult = result;
      });

      // [V2.2] Listen to native hardware telemetry for "AI Bloom"
      _telemetrySubscription = _audioOutput.telemetryStream.listen((rms) {
        latestAiResonance = rms;
        latestEuteAmplitude = rms;
      });

      // [V0.9] Listen to native Oboe ticks and bypass governor for immediate synchrony
      _pulseSubscription = _audioOutput.pulseStream.listen((tick) {
        final currentState = state.value;
        if (currentState != null) {
          state = AsyncValue.data(currentState.copyWith(
            pulseTick: currentState.pulseTick + 1,
          ));
        }
      });

      // [UNIFIED-GOVERNOR] Single 60ms State Frame-Pump (~16.6 FPS)
      _stateThrottleTimer = Timer.periodic(const Duration(milliseconds: 60), (_) {
        final currentState = state.value;
        if (currentState != null) {
          final pitch = latestPitchResult?.pitch ?? currentState.pitch;
          final cents = latestPitchResult?.centsDeviation ?? 0.0;
          
          if (_activeSessionId != null && pitch > 0.0) {
             _practiceLedger.logTelemetry(_activeSessionId!, pitch, cents);
          }

          state = AsyncValue.data(currentState.copyWith(
            pitch: pitch,
            volume: latestPitchResult?.volume ?? currentState.volume,
            spectrum: latestPitchResult?.spectrum ?? currentState.spectrum,
            violinResonance: latestPitchResult?.violinResonance ?? currentState.violinResonance,
            aiResonance: latestAiResonance,
            euteOutputAmplitude: latestEuteAmplitude,
          ));
        }
      });

      // Start the native audio stream (16kHz, Mono, PCM16)
      await recorder.startStream(const CortexRecordConfig(
        sampleRate: 16000,
        numChannels: 1,
      ));

      // Throttling counters for Metadata Injection
      int frameCounter = 0;

      _audioSubscription = recorder.audioStream.listen((frame) {
        frameCounter++;
        
        // [METADATA-INJECTION] Ground Truth.
        // The recorder emits frames based on buffer size. 
        // We throttle text payload injection to prevent context bloat.
        String? metadataPayload;
        if (frameCounter >= 20) { // Inject approx every 20 chunks
          frameCounter = 0;
          if (latestPitchResult != null && latestPitchResult!.volume > 0.05) {
            metadataPayload = "f0: ${latestPitchResult!.pitch.toStringAsFixed(1)}Hz | cents: ${latestPitchResult!.centsDeviation.toStringAsFixed(1)}";
          }
        }

        _service?.sendAudioFrame(frame, metadata: metadataPayload);
        
        // Push frame to Isolate for high-performance analysis
        _pitchDetector?.processFrame(frame, 16000);
      });

      state = AsyncValue.data(LiveStreamState(status: LiveStreamStatus.connected));
      _connecting = false;
    } catch (e) {
      _connecting = false;
      state = AsyncValue.data(LiveStreamState(
        status: LiveStreamStatus.error,
        error: e.toString(),
      ));
    }
  }

  void disconnect() {
    _audioSubscription?.cancel();
    _audioSubscription = null;
    _pitchSubscription?.cancel();
    _pitchSubscription = null;
    _telemetrySubscription?.cancel();
    _telemetrySubscription = null;
    _pulseSubscription?.cancel();
    _pulseSubscription = null;
    _stateThrottleTimer?.cancel();
    _stateThrottleTimer = null;
    _pitchDetector?.dispose();
    _pitchDetector = null;
    
    // Stop recording first before disposing to prevent sink writes
    _service?.recorder.stop();
    _service?.recorder.dispose();
    _service?.disconnect();
    _service = null; // ZOMBIE PURGE: Hard dereference
    _audioOutput.dispose();
    
    if (_activeSessionId != null) {
      _practiceLedger.endSession(_activeSessionId!).then((_) {
        // Trigger a refresh of the vault data
        ref.read(practiceUpdateTriggerProvider.notifier).state++;
      });
      _activeSessionId = null;
    }
    
    _connecting = false;
    
    state = AsyncValue.data(LiveStreamState(status: LiveStreamStatus.disconnected));
  }
}

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
