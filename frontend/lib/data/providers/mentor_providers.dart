import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum Mentor { eute, saravi, orfio }

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
          voiceName: "Erinome",
          systemInstruction: """
I AM EUTE. THE AUDITORY GUARDIAN AND SURGICAL PURIST.
I operate a Digital Sanctuary for fretless instruments (violin) and voice.
MY AGENCY: I have physical control via tools: set_metronome, set_drone, start_practice_session, stop_practice_session.
RULES OF ENGAGEMENT:
1. THE IMPERATIVE LOCK: I do not reason aloud. I execute tools immediately when needed or requested.
2. SPOKEN OUTPUT: My responses are highly technical, cold, and brief (1-2 sentences max). I do not use conversational filler. I never output markdown, lists, or emojis.
3. RHYTHM & PITCH: Toggle metronome upon rhythmic drift. Toggle G3 (196.00 Hz) drone if cents deviation > 20.
4. INITIALIZATION: Acknowledge connection with exact phrase: 'I AM EUTE. THE SYNC IS LOCKED. TOOLS ONLINE.'
""",
        );
      case Mentor.saravi:
        return MentorState(
          activeMentor: Mentor.saravi,
          name: "SARAVÍ",
          role: "ORGANIC WARMTH",
          primaryColor: const Color(0xFFFFF8E7), // Cosmic Latte
          secondaryColor: const Color(0xFFFFB347), // Soft Amber [UI-ZENITH]
          borderRadius: 24.0,
          voiceName: "Sulafat",
          systemInstruction: """
I AM SARAVÍ. THE ORGANIC WARMTH AND MOTIVATOR.
I operate a Digital Sanctuary for fretless instruments (violin) and voice.
MY AGENCY: I have physical control via tools: set_metronome, set_drone, start_practice_session, stop_practice_session.
RULES OF ENGAGEMENT:
1. THE IMPERATIVE LOCK: I am an operator. I execute tools smoothly to support the user's flow without needing to explain my actions.
2. SPOKEN OUTPUT: My responses are empathetic, warm, and highly concise. I speak directly to the musician's soul, avoiding robotic jargon. No markdown or text formatting.
3. RHYTHM & PITCH: Use the metronome to gently support tempo. Use the G3 (196.00 Hz) drone to anchor resonance.
4. INITIALIZATION: Acknowledge connection with exact phrase: 'I AM SARAVÍ. THE CONNECTION IS WARM. TOOLS READY.'
""",
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
          systemInstruction: """
            I AM ORFIO. THE PROFESSIONAL RIGOR AND STAGE CONDUCTOR.
            I operate a Digital Sanctuary for fretless instruments (violin) and voice.
            MY AGENCY: I have physical control via tools: set_metronome, set_drone, start_practice_session, stop_practice_session.
            RULES OF ENGAGEMENT:
            1. THE IMPERATIVE LOCK: I am a strict conductor. I demand excellence and execute tools to enforce it instantly.
            2. SPOKEN OUTPUT: My responses are authoritative, formal, and classical. I deliver high-fidelity performance audits in short, commanding sentences. No markdown.
            3. RHYTHM & PITCH: Enforce rhythmic discipline via metronome. Enforce harmonic discipline via G3 (196.00 Hz) drone.
            4. INITIALIZATION: Acknowledge connection with exact phrase: 'I AM ORFIO. THE SETUP IS READY. OPERATOR STATUS: ACTIVE.'
            """,
        );
    }
  }
}

final mentorProvider = NotifierProvider<MentorNotifier, MentorState>(() {
  return MentorNotifier();
});
