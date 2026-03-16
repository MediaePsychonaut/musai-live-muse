import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/audio/pulse_engine.dart';
import '../../core/dsp/pitch_matrix.dart';

class HardwareState {
  final bool isMetronomeActive;
  final bool isDroneActive;
  final int bpm;
  final String key; // Drone Key
  final DateTime? lastAgencyCommandTimestamp;

  HardwareState({
    this.isMetronomeActive = false,
    this.isDroneActive = false,
    this.bpm = 60,
    this.key = 'A4',
    this.lastAgencyCommandTimestamp,
  });

  HardwareState copyWith({
    bool? isMetronomeActive,
    bool? isDroneActive,
    int? bpm,
    String? key,
    DateTime? lastAgencyCommandTimestamp,
  }) {
    return HardwareState(
      isMetronomeActive: isMetronomeActive ?? this.isMetronomeActive,
      isDroneActive: isDroneActive ?? this.isDroneActive,
      bpm: bpm ?? this.bpm,
      key: key ?? this.key,
      lastAgencyCommandTimestamp: lastAgencyCommandTimestamp ?? this.lastAgencyCommandTimestamp,
    );
  }
}

class HardwareNotifier extends StateNotifier<HardwareState> {
  final PulseEngine _pulseEngine = PulseEngine();
  final List<DateTime> _tapTimestamps = [];

  HardwareNotifier() : super(HardwareState());

  void setMetronome(bool active) {
    state = state.copyWith(isMetronomeActive: active);
    if (active) {
      _pulseEngine.start(state.bpm.toDouble());
    } else {
      _pulseEngine.stop();
    }
  }

  void setDrone(bool active) {
    state = state.copyWith(isDroneActive: active);
    if (active) {
      final freq = PitchMatrix.a440Frequencies[state.key] ?? 440.0;
      _pulseEngine.startDrone(freq);
    } else {
      _pulseEngine.stopDrone();
    }
  }

  void setBpm(int bpm) {
    state = state.copyWith(bpm: bpm);
    if (state.isMetronomeActive) {
      _pulseEngine.updateBpm(bpm.toDouble());
    }
  }

  void setSignature(int signature) {
    _pulseEngine.updateSignature(signature);
  }

  void setKey(String key) {
    state = state.copyWith(key: key);
    if (state.isDroneActive) {
      final freq = PitchMatrix.a440Frequencies[key] ?? 440.0;
      _pulseEngine.updateDroneFreq(freq);
    }
  }
  
  // TO BE CALLED BY GEMINI FUNCTION HANDLERS IN V7.0 AND UI MANUAL OVERRIDES
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

  // Calculates BPM based on manual user taps
  void tapTempo() {
    final now = DateTime.now();
    
    // Reset taps if more than 2 seconds have passed since the last tap
    if (_tapTimestamps.isNotEmpty && now.difference(_tapTimestamps.last).inSeconds > 2) {
      _tapTimestamps.clear();
    }

    _tapTimestamps.add(now);

    // Keep only the last 4 taps to calculate a moving average
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
      
      // Clamp between 30 and 300 BPM for safety
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
