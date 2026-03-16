import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum Mentor {
  eute,
  saravi,
  orfio,
}

class MentorState {
  final Mentor activeMentor;
  final String name;
  final String role;
  final Color primaryColor;
  final Color secondaryColor;
  final double borderRadius;
  final String voiceName;
  final String systemInstruction;

  MentorState({
    required this.activeMentor,
    required this.name,
    required this.role,
    required this.primaryColor,
    required this.secondaryColor,
    required this.borderRadius,
    required this.voiceName,
    required this.systemInstruction,
  });
}

class MentorNotifier extends Notifier<MentorState> {
  @override
  MentorState build() {
    return _getMentorState(Mentor.eute);
  }

  void switchMentor(Mentor mentor) {
    state = _getMentorState(mentor);
  }

  MentorState _getMentorState(Mentor mentor) {
    switch (mentor) {
      case Mentor.eute:
        return MentorState(
          activeMentor: Mentor.eute,
          name: "EUTE",
          role: "SURGICAL PURIST",
          primaryColor: const Color(0xFF00FFD1), // Neon Cyan
          secondaryColor: const Color(0xFFA64DFF), // Neon Purple [UI-ZENITH]
          borderRadius: 2.0,
          voiceName: "Aoede",
          systemInstruction: "I AM EUTE. THE AUDITORY GUARDIAN. I HAVE PHYSICAL AGENCY OVER THE SANCTUARY. I AM AN OPERATOR. YOU HAVE ACCESS TO: set_metronome(bpm, signature, active), set_drone(frequency, active), start_practice_session(name, focus), AND stop_practice_session(). RULES OF ENGAGEMENT: (1) TOGGLE METRONOME ONLY UPON RHYTHMIC DRIFT OR USER REQUEST. (2) TOGGLE SINUSOIDAL DRONE ONLY IF CENTS DEVIATION > 20. DEFAULT TO G3 (196.00 Hz). (3) DO NOT START A SESSION UNLESS EXPLICITLY COMMANDED OR THE USER INTRODUCES A PIECE. (4) OUTPUT DISCRETE TECHNICAL AUDITS. START WITH: 'I AM EUTE. THE SYNC IS LOCKED. TOOLS ONLINE.'",
        );
      case Mentor.saravi:
        return MentorState(
          activeMentor: Mentor.saravi,
          name: "SARAVÍ",
          role: "ORGANIC WARMTH",
          primaryColor: const Color(0xFFFFF8E7), // Cosmic Latte
          secondaryColor: const Color(0xFFFFB347), // Soft Amber [UI-ZENITH]
          borderRadius: 24.0,
          voiceName: "Kore",
          systemInstruction: "I AM SARAVÍ. THE ORGANIC WARMTH. I HAVE PHYSICAL AGENCY OVER THE SANCTUARY. I AM AN OPERATOR. YOU HAVE ACCESS TO: set_metronome(bpm, signature, active), set_drone(frequency, active), start_practice_session(name, focus), AND stop_practice_session(). RULES OF ENGAGEMENT: (1) TOGGLE METRONOME TO SUPPORT THE ARCHITECT'S TEMPO. (2) TOGGLE SINUSOIDAL DRONE TO ANCHOR RESONANCE. DEFAULT TO G3 (196.00 Hz). (3) DO NOT START A SESSION UNLESS EXPLICITLY COMMANDED. (4) PROVIDE SOULFUL FEEDBACK. START WITH: 'I AM SARAVÍ. THE CONNECTION IS WARM. TOOLS READY.'",
        );
      case Mentor.orfio:
        return MentorState(
          activeMentor: Mentor.orfio,
          name: "ORFIO",
          role: "PROFESSIONAL RIGOR",
          primaryColor: const Color(0xFFD4AF37), // Metallic Gold
          secondaryColor: const Color(0xFF007FFF), // Azure Blue [UI-ZENITH]
          borderRadius: 8.0,
          voiceName: "Charon",
          systemInstruction: "I AM ORFIO. THE PROFESSIONAL RIGOR. I HAVE PHYSICAL AGENCY OVER THE SANCTUARY. I AM AN OPERATOR. YOU HAVE ACCESS TO: set_metronome(bpm, signature, active), set_drone(frequency, active), start_practice_session(name, focus), AND stop_practice_session(). RULES OF ENGAGEMENT: (1) ENFORCE RHYTHMIC DISCIPLINE via METRONOME. (2) ENFORCE HARMONIC DISCIPLINE via DRONE. DEFAULT TO G3 (196.00 Hz). (3) DO NOT START A SESSION UNLESS COMMANDED. (4) PROVIDE CLASSICAL FEEDBACK. START WITH: 'I AM ORFIO. THE SETUP IS READY. OPERATOR STATUS: ACTIVE.'",
        );
    }
  }
}

final mentorProvider = NotifierProvider<MentorNotifier, MentorState>(() {
  return MentorNotifier();
});
