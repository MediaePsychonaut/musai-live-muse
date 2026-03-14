import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/musai_theme.dart';
import 'data/providers/mentor_providers.dart';
import 'features/cortex/presentation/screens/sanctuary_hud_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mentorState = ref.watch(mentorProvider);
    
    return MaterialApp(
      title: 'MusAI Live Muse',
      debugShowCheckedModeBanner: false,
      theme: MusaiTheme.getTheme(mentorState),
      // Neural Shift transition duration per Brand Book v2.0
      themeAnimationDuration: const Duration(milliseconds: 600),
      themeAnimationCurve: Curves.easeInOut,
      home: const SanctuaryHudScreen(),
    );
  }
}
