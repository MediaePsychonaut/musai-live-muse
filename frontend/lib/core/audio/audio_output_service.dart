import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AudioOutputService {
  static final AudioOutputService _instance = AudioOutputService._internal();
  factory AudioOutputService() => _instance;
  AudioOutputService._internal();

  static const _channel = MethodChannel('musai.live/audio_sink');
  static const _telemetryChannel = BasicMessageChannel<dynamic>('musai.live/audio_telemetry', StandardMessageCodec());
  static const _pulseChannel = BasicMessageChannel<dynamic>('musai.live/audio_pulse', StandardMessageCodec());

  final _telemetryController = StreamController<double>.broadcast();
  Stream<double> get telemetryStream => _telemetryController.stream;

  final _pulseController = StreamController<int>.broadcast();
  Stream<int> get pulseStream => _pulseController.stream;

  bool _initialized = false;
  
  Future<void> init() async {
    if (_initialized) return;
    
    try {
      await _channel.invokeMethod('init', {'sampleRate': 24000});
      _telemetryChannel.setMessageHandler((message) async {
        if (_telemetryController.isClosed) return null;
        if (message is double) {
          _telemetryController.add(message);
        } else if (message is int) {
          _telemetryController.add(message.toDouble());
        }
        return null;
      });
      _pulseChannel.setMessageHandler((message) async {
        if (_pulseController.isClosed) return null;
        if (message is int) {
          _pulseController.add(message);
        }
        return null;
      });
      _initialized = true;
    } catch (e) {
      debugPrint("NATIVE_SINK_ERROR: [INIT] $e");
    }
  }

  /// Plays 24kHz PCM 16-bit Mono chunks from Gemini
  void playChunk(Uint8List chunk) {
    if (!_initialized) {
      init().then((_) {
        _invokeWrite(chunk);
      });
      return;
    }
    _invokeWrite(chunk);
  }

  void _invokeWrite(Uint8List chunk) {
    _channel.invokeMethod('write', {'data': chunk}).catchError((e) {
      debugPrint("NATIVE_SINK_ERROR: [WRITE] $e");
    });
  }

  void clearVocalBuffer() {
    _channel.invokeMethod('clearVocal').catchError((e) {
      debugPrint("NATIVE_SINK_ERROR: [CLEAR_VOCAL] $e");
    });
  }

  void dispose() {
    _channel.invokeMethod('dispose');
    _telemetryChannel.setMessageHandler(null);
    _pulseChannel.setMessageHandler(null);
    _initialized = false;
    if (!_telemetryController.isClosed) _telemetryController.close();
    if (!_pulseController.isClosed) _pulseController.close();
  }
}
