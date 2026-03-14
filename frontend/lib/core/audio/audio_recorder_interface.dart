import 'dart:async';
import 'dart:typed_data';

abstract class CortexRecorder {
  Future<bool> hasPermission();
  Future<void> startStream(CortexRecordConfig config);
  Future<void> stop();
  Future<void> dispose();
  Stream<Uint8List> get audioStream;
}

class CortexRecordConfig {
  final int sampleRate;
  final int numChannels;
  final CortexAudioEncoder encoder;

  const CortexRecordConfig({
    this.sampleRate = 16000,
    this.numChannels = 1,
    this.encoder = CortexAudioEncoder.pcm16bits,
  });
}

enum CortexAudioEncoder {
  pcm16bits,
}
