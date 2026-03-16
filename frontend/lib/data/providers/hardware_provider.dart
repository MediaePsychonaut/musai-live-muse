import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/audio/pulse_engine.dart';
import '../../core/dsp/pitch_matrix.dart';

class HardwareState {
  final bool isMetronomeActive;
  final bool isDroneActive;
  final int bpm;
  final int signature; // Time Signature numerator
  final String key; // Drone Key
  final DateTime? lastAgencyCommandTimestamp;

  HardwareState({
    this.isMetronomeActive = false,
    this.isDroneActive = false,
    this.bpm = 60,
    this.signature = 4,
    this.key = 'A4',
    this.lastAgencyCommandTimestamp,
  });

  HardwareState copyWith({
    bool? isMetronomeActive,
    bool? isDroneActive,
    int? bpm,
    int? signature,
    String? key,
    DateTime? lastAgencyCommandTimestamp,
  }) {
    return HardwareState(
      isMetronomeActive: isMetronomeActive ?? this.isMetronomeActive,
      isDroneActive: isDroneActive ?? this.isDroneActive,
      bpm: bpm ?? this.bpm,
      signature: signature ?? this.signature,
      key: key ?? this.key,
      lastAgencyCommandTimestamp: lastAgencyCommandTimestamp ?? this.lastAgencyCommandTimestamp,
    );
  }
}

class HardwareNotifier extends StateNotifier<HardwareState> {
  final PulseEngine _pulseEngine = PulseEngine();
  final List<DateTime> _tapTimestamps = [];

  HardwareNotifier() : super(HardwareState());

  void _ensureStableState(Function() action) {
    // [HARDENING-REPAIR] Absolute synchronous state flux.
    // Legacy microtasks caused race-conditions during rapid AI batch commands.
    action();
  }

  void setMetronome(bool active) {
    _ensureStableState(() {
      state = state.copyWith(isMetronomeActive: active);
      if (active) {
        _pulseEngine.start(state.bpm.toDouble());
      } else {
        _pulseEngine.stop();
      }
    });
  }

  void setDrone(bool active, {double? frequency}) {
    _ensureStableState(() {
      state = state.copyWith(isDroneActive: active);
      if (active) {
        final freq = frequency ?? PitchMatrix.a440Frequencies[state.key] ?? 196.0;
        _pulseEngine.startDrone(freq);
      } else {
        _pulseEngine.stopDrone();
      }
    });
  }

  void setBpm(int bpm) {
    _ensureStableState(() {
      state = state.copyWith(bpm: bpm);
      if (state.isMetronomeActive) {
        _pulseEngine.updateBpm(bpm.toDouble());
      }
    });
  }

  void setSignature(int signature) {
    _ensureStableState(() {
      state = state.copyWith(signature: signature);
      _pulseEngine.updateSignature(signature);
    });
  }

  void setKey(String key) {
    _ensureStableState(() {
      state = state.copyWith(key: key);
      if (state.isDroneActive) {
        final freq = PitchMatrix.a440Frequencies[key] ?? 196.0;
        _pulseEngine.updateDroneFreq(freq);
      }
    });
  }
  
  void toggleMetronome() {
    final newState = !state.isMetronomeActive;
    state = state.copyWith(isMetronomeActive: newState);
    if (newState) {
      _pulseEngine.start(state.bpm.toDouble());
    } else {
      _pulseEngine.stop();
    }
  }

  void toggleDrone() {
    final newState = !state.isDroneActive;
    state = state.copyWith(isDroneActive: newState);
    if (newState) {
      final freq = PitchMatrix.a440Frequencies[state.key] ?? 440.0;
      _pulseEngine.startDrone(freq);
    } else {
      _pulseEngine.stopDrone();
    }
  }

  void tapTempo() {
    final now = DateTime.now();
    if (_tapTimestamps.isNotEmpty && now.difference(_tapTimestamps.last).inSeconds > 2) {
      _tapTimestamps.clear();
    }
    _tapTimestamps.add(now);
    if (_tapTimestamps.length > 4) {
      _tapTimestamps.removeAt(0);
    }
    if (_tapTimestamps.length >= 2) {
      int totalMs = 0;
      for (int i = 1; i < _tapTimestamps.length; i++) {
        totalMs += _tapTimestamps[i].difference(_tapTimestamps[i - 1]).inMilliseconds;
      }
      final averageMs = totalMs / (_tapTimestamps.length - 1);
      final derivedBpm = (60000 / averageMs).round();
      if (derivedBpm >= 30 && derivedBpm <= 300) {
        setBpm(derivedBpm);
      }
    }
  }

  void triggerAgencyPulse() {
    state = state.copyWith(lastAgencyCommandTimestamp: DateTime.now());
  }
}

final hardwareProvider = StateNotifierProvider<HardwareNotifier, HardwareState>((ref) {
  return HardwareNotifier();
});
