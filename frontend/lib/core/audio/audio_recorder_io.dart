import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'audio_recorder_interface.dart';

class CortexRecorderImpl implements CortexRecorder {
  final _record = AudioRecorder();
  Stream<Uint8List>? _audioStream;

  @override
  Future<bool> hasPermission() => _record.hasPermission();

  @override
  Future<void> startStream(CortexRecordConfig config) async {
    final recordConfig = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: config.sampleRate,
      numChannels: config.numChannels,
    );
    
    _audioStream = await _record.startStream(recordConfig);
  }

  @override
  Stream<Uint8List> get audioStream => _audioStream ?? const Stream.empty();

  @override
  Future<void> stop() => _record.stop();

  @override
  Future<void> dispose() => _record.dispose();
}

CortexRecorder createRecorder() => CortexRecorderImpl();
