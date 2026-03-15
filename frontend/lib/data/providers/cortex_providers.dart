import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/audio/audio_recorder.dart';
import '../../core/audio/audio_output_service.dart';
import '../../core/dsp/pitch_detector.dart';
import '../../core/secrets/secret_manager.dart';
import '../services/gemini_live_service.dart';
import 'mentor_providers.dart';

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

  LiveStreamState({
    required this.status,
    this.error,
    this.volume = 0.0,
    this.pitch = 0.0,
    this.spectrum = const [],
    this.violinResonance = 0.0,
    this.aiResonance = 0.0,
    this.euteOutputAmplitude = 0.0,
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
    );
  }
}

class LiveStreamNotifier extends AsyncNotifier<LiveStreamState> {
  GeminiLiveService? _service;
  StreamSubscription? _audioSubscription;
  PitchDetector? _pitchDetector;
  StreamSubscription? _pitchSubscription;
  StreamSubscription? _telemetrySubscription;
  final _audioOutput = AudioOutputService();
  bool _connecting = false;

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
      
      final currentMentor = ref.read(mentorProvider);

      _service?.disconnect();
      _service = GeminiLiveService(apiKey, recorder, currentMentor);

      await _service!.connect(
        onMessage: (msg) {
          // 1. Handle Audio Chunks (24kHz PCM) - [MISSION: GAPLESS]
          final audioChunk = msg['audio_chunk'];
          if (audioChunk != null && audioChunk is Uint8List) {
            // Push directly to native sink for zero-stutter gapless playback
            _audioOutput.playChunk(audioChunk);
          }

          // 2. Process technical feedback from EUTE
          final serverContent = msg['serverContent'];
          if (serverContent != null) {
            final modelTurn = serverContent['modelTurn'];
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
      );

      // [SEQUENTIAL-HANDSHAKE] Setup is strictly complete. Activate Audio Pipeline.
      debugPrint("MUSE_LOG: [EUTE] Protocol Synchronized. Activating Audio Pipeline...");

      DateTime lastTelemetryUpdate = DateTime.now();

      // Initialize Pitch Detector Isolate
      _pitchDetector = PitchDetector();
      await _pitchDetector!.init();
      DateTime lastUpdate = DateTime.now();
      _pitchSubscription = _pitchDetector!.results.listen((result) {
        final now = DateTime.now();
        if (now.difference(lastUpdate).inMilliseconds < 40) return;
        
        lastUpdate = now;
        final currentState = state.value;
        if (currentState != null) {
          state = AsyncValue.data(currentState.copyWith(
            pitch: result.pitch,
            volume: result.volume,
            spectrum: result.spectrum,
            violinResonance: result.violinResonance,
          ));
        }
      });

      // [V2.2] Listen to native hardware telemetry for "AI Bloom"
      _telemetrySubscription = _audioOutput.telemetryStream.listen((rms) {
        final now = DateTime.now();
        if (now.difference(lastTelemetryUpdate).inMilliseconds < 50) return;
        
        lastTelemetryUpdate = now;
        final currentState = state.value;
        if (currentState != null) {
          state = AsyncValue.data(currentState.copyWith(
            aiResonance: rms,
            euteOutputAmplitude: rms, // Direct binding for Bloom pulse
          ));
        }
      });

      // Start the native audio stream (16kHz, Mono, PCM16)
      await recorder.startStream(const CortexRecordConfig(
        sampleRate: 16000,
        numChannels: 1,
      ));

      _audioSubscription = recorder.audioStream.listen((frame) {
        _service?.sendAudioFrame(frame);
        
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
    _pitchSubscription?.cancel();
    _telemetrySubscription?.cancel();
    _pitchDetector?.dispose();
    _pitchDetector = null;
    
    _service?.recorder.stop();
    _service?.recorder.dispose();
    _service?.disconnect();
    _service = null; // ZOMBIE PURGE: Hard dereference
    _audioOutput.dispose();
    _connecting = false;
    
    state = AsyncValue.data(LiveStreamState(status: LiveStreamStatus.disconnected));
  }
}

final liveStreamStateProvider = AsyncNotifierProvider<LiveStreamNotifier, LiveStreamState>(() {
  return LiveStreamNotifier();
});
