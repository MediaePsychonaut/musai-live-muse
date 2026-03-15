import 'package:flutter_riverpod/flutter_riverpod.dart';

class HardwareState {
  final bool isMetronomeActive;
  final bool isDroneActive;
  final int bpm;
  final String key; // Drone Key

  HardwareState({
    this.isMetronomeActive = false,
    this.isDroneActive = false,
    this.bpm = 60,
    this.key = 'A',
  });

  HardwareState copyWith({
    bool? isMetronomeActive,
    bool? isDroneActive,
    int? bpm,
    String? key,
  }) {
    return HardwareState(
      isMetronomeActive: isMetronomeActive ?? this.isMetronomeActive,
      isDroneActive: isDroneActive ?? this.isDroneActive,
      bpm: bpm ?? this.bpm,
      key: key ?? this.key,
    );
  }
}

class HardwareNotifier extends StateNotifier<HardwareState> {
  HardwareNotifier() : super(HardwareState());

  void setMetronome(bool active) => state = state.copyWith(isMetronomeActive: active);
  void setDrone(bool active) => state = state.copyWith(isDroneActive: active);
  void setBpm(int bpm) => state = state.copyWith(bpm: bpm);
  void setKey(String key) => state = state.copyWith(key: key);
  
  // TO BE CALLED BY GEMINI FUNCTION HANDLERS IN V7.0
  void toggleMetronome() => state = state.copyWith(isMetronomeActive: !state.isMetronomeActive);
  void toggleDrone() => state = state.copyWith(isDroneActive: !state.isDroneActive);
}

final hardwareProvider = StateNotifierProvider<HardwareNotifier, HardwareState>((ref) {
  return HardwareNotifier();
});
