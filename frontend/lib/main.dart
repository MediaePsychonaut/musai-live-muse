import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/musai_theme.dart';
import 'features/cortex/presentation/screens/sanctuary_hud_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MusAI Live Muse',
      debugShowCheckedModeBanner: false,
      theme: MusaiTheme.darkTheme,
      home: const SanctuaryHudScreen(),
    );
  }
}
