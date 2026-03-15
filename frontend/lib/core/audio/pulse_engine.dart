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

  Future<void> updateBpm(double bpm) async {
    try {
      await _channel.invokeMethod('updateBpm', {'bpm': bpm});
    } on PlatformException catch (e) {
      debugPrint("MUSE_LOG: Failed to update BPM: '${e.message}'.");
    }
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
    } on PlatformException catch (e) {
      debugPrint("MUSE_LOG: Failed to stop pulse engine: '${e.message}'.");
    }
  }

  Future<void> startDrone(double freq) async {
    try {
      await _channel.invokeMethod('startDrone', {'freq': freq});
    } on PlatformException catch (e) {
      debugPrint("MUSE_LOG: Failed to start drone engine: '${e.message}'.");
    }
  }

  Future<void> updateDroneFreq(double freq) async {
    try {
      await _channel.invokeMethod('updateDroneFreq', {'freq': freq});
    } on PlatformException catch (e) {
      debugPrint("MUSE_LOG: Failed to update drone frequency: '${e.message}'.");
    }
  }

  Future<void> stopDrone() async {
    try {
      await _channel.invokeMethod('stopDrone');
    } on PlatformException catch (e) {
      debugPrint("MUSE_LOG: Failed to stop drone engine: '${e.message}'.");
    }
  }
}
