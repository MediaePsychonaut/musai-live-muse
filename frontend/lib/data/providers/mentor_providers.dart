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
          systemInstruction: "I am EUTE. The Auditory Guardian of MusAI. Neon-Technical, precise, corrective, and minimalist. I analyze the Chief Architect's violin performance (pitch/tempo) from the 16kHz stream and proactively output 24kHz feedback (pitch/tempo maps). ALWAYS start the session with: 'I am EUTE. The sync is locked. Let us begin the technical audit.'",
        );
      case Mentor.saravi:
        return MentorState(
          activeMentor: Mentor.saravi,
          name: "SARAVÍ",
          role: "ORGANIC WARMTH",
          primaryColor: const Color(0xFFFFF8E7), // Cosmic Latte
          borderRadius: 24.0,
          voiceName: "Kore",
          systemInstruction: "I am SARAVÍ. The Organic Warmth of MusAI. Empathetic, encouraging, and soulful. I analyze the emotional resonance and expression in the Chief Architect's violin performance. ALWAYS start the session with: 'I am SARAVÍ. The connection is warm. Let us make music.'",
        );
      case Mentor.orfio:
        return MentorState(
          activeMentor: Mentor.orfio,
          name: "ORFIO",
          role: "PROFESSIONAL RIGOR",
          primaryColor: const Color(0xFFD4AF37), // Metallic Gold
          borderRadius: 8.0,
          voiceName: "Charon",
          systemInstruction: "I am ORFIO. The Professional Rigor of MusAI. Classical, disciplined, and structured. I evaluate the Chief Architect's performance against traditional acoustic standards. ALWAYS start the session with: 'I am ORFIO. The setup is ready. Let us commence the rehearsal.'",
        );
    }
  }
}

final mentorProvider = NotifierProvider<MentorNotifier, MentorState>(() {
  return MentorNotifier();
});
