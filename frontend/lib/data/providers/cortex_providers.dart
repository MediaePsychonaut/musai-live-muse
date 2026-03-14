import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/audio/audio_recorder.dart';
import '../../core/dsp/pitch_detector.dart';
import '../../core/secrets/secret_manager.dart';
import '../services/gemini_live_service.dart';

enum LiveStreamStatus { disconnected, connecting, connected, error }

class LiveStreamState {
  final LiveStreamStatus status;
  final String? error;
  final double volume; // 0.0 to 1.0Base
  final double pitch;

  LiveStreamState({
    required this.status,
    this.error,
    this.volume = 0.0,
    this.pitch = 0.0,
  });

  LiveStreamState copyWith({
    LiveStreamStatus? status,
    String? error,
    double? volume,
    double? pitch,
  }) {
    return LiveStreamState(
      status: status ?? this.status,
      error: error ?? this.error,
      volume: volume ?? this.volume,
      pitch: pitch ?? this.pitch,
    );
  }
}

class LiveStreamNotifier extends AsyncNotifier<LiveStreamState> {
  GeminiLiveService? _service;
  StreamSubscription? _audioSubscription;
  PitchDetector? _pitchDetector;
  StreamSubscription? _pitchSubscription;

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
      
      _service?.disconnect();
      _service = GeminiLiveService(apiKey, recorder);

      await _service!.connect(
        onMessage: (msg) {
          // Future: Process technical feedback from EUTE
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

      // Initialize Pitch Detector Isolate
      _pitchDetector = PitchDetector();
      await _pitchDetector!.init();
      
      _pitchSubscription = _pitchDetector!.results.listen((result) {
        final currentState = state.value;
        if (currentState != null) {
          state = AsyncValue.data(currentState.copyWith(
            pitch: result.pitch,
            volume: result.volume,
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
    _pitchDetector?.dispose();
    _pitchDetector = null;
    
    _service?.recorder.stop();
    _service?.recorder.dispose();
    _service?.disconnect();
    state = AsyncValue.data(LiveStreamState(status: LiveStreamStatus.disconnected));
  }
}

final liveStreamStateProvider = AsyncNotifierProvider<LiveStreamNotifier, LiveStreamState>(() {
  return LiveStreamNotifier();
});
