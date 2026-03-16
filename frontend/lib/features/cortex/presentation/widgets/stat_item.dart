import 'package:flutter/material.dart';
import '../../../../core/theme/musai_theme.dart';

class StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const StatItem({
    super.key,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final displayColor = color ?? MusaiTheme.parchment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: displayColor.withAlpha(128),
            letterSpacing: 1.5,
            fontFamily: 'SpaceMono',
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            color: displayColor,
            fontWeight: FontWeight.w900,
            fontFamily: 'Montserrat',
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}
