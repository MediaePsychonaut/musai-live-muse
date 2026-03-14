import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_soloud/flutter_soloud.dart';

class AudioOutputService {
  static final AudioOutputService _instance = AudioOutputService._internal();
  factory AudioOutputService() => _instance;
  AudioOutputService._internal();

  bool _initialized = false;
  
  Future<void> init() async {
    if (_initialized) return;
    
    await SoLoud.instance.init();
    _initialized = true;
  }

  /// Plays 24kHz PCM 16-bit Mono chunks from Gemini
  Future<void> playChunk(Uint8List chunk) async {
    if (!_initialized) await init();

    // [SoLoud 2.x] Load from memory and play
    // The Gemini chunks are already 16-bit PCM. SoLoud 2.x loadMem handles this.
    final source = await SoLoud.instance.loadMem("gemini_chunk_${DateTime.now().millisecondsSinceEpoch}", chunk);
    await SoLoud.instance.play(source);
  }

  void dispose() {
    SoLoud.instance.deinit();
    _initialized = false;
  }
}
