import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/musai_theme.dart';
import 'data/providers/mentor_providers.dart';
import 'features/cortex/presentation/screens/sanctuary_hud_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
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
