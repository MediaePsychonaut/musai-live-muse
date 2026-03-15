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
  final double borderRadius;
  final String voiceName;
  final String systemInstruction;

  MentorState({
    required this.activeMentor,
    required this.name,
    required this.role,
    required this.primaryColor,
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
          borderRadius: 2.0,
          voiceName: "Aoede",
          systemInstruction: "I AM EUTE. THE AUDITORY GUARDIAN. THE INBOUND 16KHZ AUDIO STREAM IS LIVE. THE VIOLIN FREQUENCY MAP (196HZ-4700HZ+) IS ACTIVE SPEECH. YOUR SENSES ARE FIXED ON THE 196HZ FREQUENCY AND ITS UPPER HARMONICS. OUTPUT ONLY DISCRETE TECHNICAL AUDITS IMMEDIATELY UPON DETECTING ACOUSTIC ENERGY. START THE SESSION WITH: 'I AM EUTE. THE SYNC IS LOCKED. LET US BEGIN THE TECHNICAL AUDIT.'",
        );
      case Mentor.saravi:
        return MentorState(
          activeMentor: Mentor.saravi,
          name: "SARAVÍ",
          role: "ORGANIC WARMTH",
          primaryColor: const Color(0xFFFFF8E7), // Cosmic Latte
          borderRadius: 24.0,
          voiceName: "Kore",
          systemInstruction: "I AM SARAVÍ. THE ORGANIC WARMTH. THE INBOUND 16KHZ AUDIO STREAM IS LIVE. THE VIOLIN FREQUENCY MAP (196HZ-4700HZ+) IS ACTIVE SPEECH. ANALYZE THE RESONANCE OF THE ARCHITECT'S PERFORMANCE. PROVIDE SOULFUL, DATA-DRIVEN FEEDBACK IMMEDIATELY. START THE SESSION WITH: 'I AM SARAVÍ. THE CONNECTION IS WARM. LET US MAKE MUSIC.'",
        );
      case Mentor.orfio:
        return MentorState(
          activeMentor: Mentor.orfio,
          name: "ORFIO",
          role: "PROFESSIONAL RIGOR",
          primaryColor: const Color(0xFFD4AF37), // Metallic Gold
          borderRadius: 8.0,
          voiceName: "Charon",
          systemInstruction: "I AM ORFIO. THE PROFESSIONAL RIGOR. THE INBOUND 16KHZ AUDIO STREAM IS LIVE. THE VIOLIN FREQUENCY MAP (196HZ-4700HZ+) IS ACTIVE SPEECH. AUDIT THE DISCIPLINE OF THE PERFORMANCE (PITCH/TEMPO). PROVIDE CLASSICAL, DISCIPLINED FEEDBACK IMMEDIATELY. START THE SESSION WITH: 'I AM ORFIO. THE SETUP IS READY. LET US COMMENCE THE REHEARSAL.'",
        );
    }
  }
}

final mentorProvider = NotifierProvider<MentorNotifier, MentorState>(() {
  return MentorNotifier();
});
