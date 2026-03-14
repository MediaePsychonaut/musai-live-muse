import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/audio/audio_recorder.dart';
import '../../core/audio/audio_output_service.dart';
import '../../core/audio/jitter_buffer.dart';
import '../../core/dsp/pitch_detector.dart';
import '../../core/secrets/secret_manager.dart';
import '../services/gemini_live_service.dart';

enum LiveStreamStatus { disconnected, connecting, connected, error }

class LiveStreamState {
  final LiveStreamStatus status;
  final String? error;
  final double volume; // 0.0 to 1.0Base
  final double pitch;
  final List<double> spectrum; // FFT Telemetry
  final double violinResonance;

  LiveStreamState({
    required this.status,
    this.error,
    this.volume = 0.0,
    this.pitch = 0.0,
    this.spectrum = const [],
    this.violinResonance = 0.0,
  });

  LiveStreamState copyWith({
    LiveStreamStatus? status,
    String? error,
    double? volume,
    double? pitch,
    List<double>? spectrum,
    double? violinResonance,
  }) {
    return LiveStreamState(
      status: status ?? this.status,
      error: error ?? this.error,
      volume: volume ?? this.volume,
      pitch: pitch ?? this.pitch,
      spectrum: spectrum ?? this.spectrum,
      violinResonance: violinResonance ?? this.violinResonance,
    );
  }
}

class LiveStreamNotifier extends AsyncNotifier<LiveStreamState> {
  GeminiLiveService? _service;
  StreamSubscription? _audioSubscription;
  PitchDetector? _pitchDetector;
  StreamSubscription? _pitchSubscription;
  final _audioOutput = AudioOutputService();
  final _jitterBuffer = JitterBuffer();
  Timer? _playbackTimer;

  @override
  FutureOr<LiveStreamState> build() {
    return LiveStreamState(status: LiveStreamStatus.disconnected);
  }

  Future<void> connect() async {
    state = AsyncValue.data(LiveStreamState(status: LiveStreamStatus.connecting));

    try {
      final recorder = createRecorder();
      
      final hasPermission = await recorder.hasPermission();
      if (!hasPermission) {
        state = AsyncValue.data(LiveStreamState(
          status: LiveStreamStatus.error,
          error: "PERMISSION_DENIED: Microphone access is required.",
        ));
        return;
      }

      final apiKey = SecretManager().apiKey;
      
      // Initialize SoLoud for Output
      await _audioOutput.init();
      
      _service?.disconnect();
      _service = GeminiLiveService(apiKey, recorder);

      await _service!.connect(
        onMessage: (msg) {
          // 1. Handle Audio Chunks (24kHz PCM)
          final audioChunk = msg['audio_chunk'];
          if (audioChunk != null && audioChunk is Uint8List) {
            _jitterBuffer.addChunk(audioChunk);
          }

          // 2. Process technical feedback from EUTE
          final serverContent = msg['server_content'];
          if (serverContent != null) {
            final modelTurn = serverContent['model_turn'];
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
          state = AsyncValue.data(LiveStreamState(
            status: LiveStreamStatus.error,
            error: "SYNC_FAIL: ${err.toString()}",
          ));
        },
        onDone: () {
          disconnect();
        },
      );

      // [SEQUENTIAL-HANDSHAKE] Setup is strictly complete. Activate Audio Pipeline.
      debugPrint("MUSE_LOG: [EUTE] Protocol Synchronized. Activating Audio Pipeline...");

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


      // [JITTER-BUFFER] Playback Loop
      _playbackTimer = Timer.periodic(const Duration(milliseconds: 20), (timer) async {
        if (_jitterBuffer.hasSufficientData || (!_jitterBuffer.isEmpty && timer.tick > 50)) {
          final chunk = _jitterBuffer.nextChunk();
          if (chunk != null) {
            await _audioOutput.playChunk(chunk);
          }
        }
      });

      state = AsyncValue.data(LiveStreamState(status: LiveStreamStatus.connected));
    } catch (e) {
      state = AsyncValue.data(LiveStreamState(
        status: LiveStreamStatus.error,
        error: e.toString(),
      ));
    }
  }

  void disconnect() {
    _audioSubscription?.cancel();
    _pitchSubscription?.cancel();
    _playbackTimer?.cancel();
    _jitterBuffer.clear();
    _pitchDetector?.dispose();
    _pitchDetector = null;
    
    _service?.recorder.stop();
    _service?.recorder.dispose();
    _service?.disconnect();
    _audioOutput.dispose();
    
    state = AsyncValue.data(LiveStreamState(status: LiveStreamStatus.disconnected));
  }
}

final liveStreamStateProvider = AsyncNotifierProvider<LiveStreamNotifier, LiveStreamState>(() {
  return LiveStreamNotifier();
});
