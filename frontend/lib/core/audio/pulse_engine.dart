import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class PulseEngine {
  static const MethodChannel _channel = MethodChannel('com.example.frontend/pulse_engine');

  Future<void> start(double bpm) async {
    try {
      await _channel.invokeMethod('start', {'bpm': bpm});
    } on PlatformException catch (e) {
      debugPrint("MUSE_LOG: Failed to start pulse engine: '${e.message}'.");
    }
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
    } on PlatformException catch (e) {
      debugPrint("MUSE_LOG: Failed to stop pulse engine: '${e.message}'.");
    }
  }
}
