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

  MentorState({
    required this.activeMentor,
    required this.name,
    required this.role,
    required this.primaryColor,
    required this.borderRadius,
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
        );
      case Mentor.saravi:
        return MentorState(
          activeMentor: Mentor.saravi,
          name: "SARAVÍ",
          role: "ORGANIC WARMTH",
          primaryColor: const Color(0xFFFFF8E7), // Cosmic Latte
          borderRadius: 24.0,
        );
      case Mentor.orfio:
        return MentorState(
          activeMentor: Mentor.orfio,
          name: "ORFIO",
          role: "PROFESSIONAL RIGOR",
          primaryColor: const Color(0xFFD4AF37), // Metallic Gold
          borderRadius: 8.0,
        );
    }
  }
}

final mentorProvider = NotifierProvider<MentorNotifier, MentorState>(() {
  return MentorNotifier();
});
