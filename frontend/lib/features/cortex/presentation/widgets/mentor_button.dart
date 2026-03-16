import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/providers/mentor_providers.dart';
import '../../../../data/providers/cortex_providers.dart';

class MentorButton extends ConsumerWidget {
  final Mentor mentor;
  final String label;

  const MentorButton({
    super.key,
    required this.mentor,
    required this.label,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mentorState = ref.watch(mentorProvider);
    final activeMentor = mentorState.activeMentor;
    final isActive = activeMentor == mentor;
    final primaryColor = mentorState.primaryColor;
    
    return Tooltip(
      message: "Switch to ${mentor.name.toUpperCase()}",
      child: InkWell(
        onTap: () {
          ref.read(liveStreamStateProvider.notifier).disconnect();
          ref.read(mentorProvider.notifier).switchMentor(mentor);
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? primaryColor.withAlpha(40) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? primaryColor : Colors.white10,
              width: 1,
            ),
            boxShadow: isActive ? [
              BoxShadow(
                color: primaryColor.withAlpha(20),
                blurRadius: 10,
              )
            ] : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/icons/${mentor.name}_icon.png', 
                width: 20, 
                height: 20, 
                color: isActive ? Colors.white : Colors.white38,
                errorBuilder: (c, e, s) => Icon(
                  Icons.person_outline,
                  size: 16,
                  color: isActive ? Colors.white : Colors.white38,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white30,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  letterSpacing: 2,
                  fontSize: 12,
                  fontFamily: 'Montserrat',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
