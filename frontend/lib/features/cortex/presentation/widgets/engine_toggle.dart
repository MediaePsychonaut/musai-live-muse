import 'package:flutter/material.dart';

class EngineToggle extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color color;

  const EngineToggle({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isActive ? color : color.withAlpha(50),
            width: 1,
          ),
          color: isActive ? color.withAlpha(30) : Colors.transparent,
          boxShadow: isActive ? [
            BoxShadow(
              color: color.withAlpha(40),
              blurRadius: 8,
              spreadRadius: 1,
            )
          ] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? color : color.withAlpha(100),
            fontSize: 10,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            letterSpacing: 1.5,
            fontFamily: 'SpaceMono',
          ),
        ),
      ),
    );
  }
}
