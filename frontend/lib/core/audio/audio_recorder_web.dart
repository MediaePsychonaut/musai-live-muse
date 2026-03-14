import 'dart:async';
import 'package:flutter/foundation.dart';
import 'audio_recorder_interface.dart';

class MockCortexRecorder implements CortexRecorder {
  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<void> startStream(CortexRecordConfig config) async {
    // Web Mock: No-op to bypass record_web compiler error
    debugPrint("MUSE_DEBUG: Web Audio Recorder Stream Started (Mock)");
  }

  @override
  Stream<Uint8List> get audioStream => const Stream.empty();

  @override
  Future<void> stop() async {
    debugPrint("MUSE_DEBUG: Web Audio Recorder Stopped (Mock)");
  }

  @override
  Future<void> dispose() async {}
}

CortexRecorder createRecorder() => MockCortexRecorder();
