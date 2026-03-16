import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/musai_theme.dart';
import '../../../../data/providers/cortex_providers.dart';
import '../../../../data/providers/mentor_providers.dart';
import 'stat_item.dart';
import 'trend_chart.dart';

class ProgressView extends ConsumerWidget {
  const ProgressView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(progressStatsProvider);
    final telemetryAsync = ref.watch(recentTelemetryProvider);

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "PROGRESS VAULT",
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              color: MusaiTheme.parchment,
              fontSize: 32,
            ),
          ),
          Text(
            "CHRONICLES OF THE SHARED DEMIURGE",
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              letterSpacing: 4,
              color: MusaiTheme.parchment.withAlpha(100),
            ),
          ),
          const SizedBox(height: 40),
          
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withAlpha(10)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  statsAsync.when(
                    data: (stats) {
                      final mentor = ref.watch(mentorProvider);
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          StatItem(label: "SESSIONS", value: "${stats['totalSessions']}"),
                          StatItem(label: "TOTAL TIME", value: "${(stats['totalHours'] as double).toStringAsFixed(1)}h"),
                          StatItem(label: "AVG PRECISION", value: "${(stats['avgPrecision'] as double).toStringAsFixed(1)}%", color: mentor.primaryColor),
                        ],
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator(color: MusaiTheme.deepSpaceTeal, strokeWidth: 1)),
                    error: (err, st) => const Text("Error loading stats", style: TextStyle(color: Colors.red)),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  Expanded(
                    child: telemetryAsync.when(
                      data: (telemetry) {
                        if (telemetry.isEmpty) {
                          return const Center(
                            child: Text(
                              "NO TELEMETRY AVAILABLE YET.\nBEGIN A SESSION TO CHART PROGRESS.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white24,
                                letterSpacing: 2,
                                fontSize: 10,
                                fontFamily: 'SpaceMono',
                              ),
                            ),
                          );
                        }
                        final mentor = ref.watch(mentorProvider);
                        return TrendChart(telemetry: telemetry, color: mentor.primaryColor);
                      },
                      loading: () => const Center(child: CircularProgressIndicator(color: MusaiTheme.deepSpaceTeal, strokeWidth: 1)),
                      error: (e, st) => const Center(child: Text("FAILED TO LOAD TELEMETRY", style: TextStyle(color: Colors.red))),
                    )
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          Center(
            child: Text(
              "SWIPE RIGHT TO RETURN TO SANCTUARY",
              style: TextStyle(
                color: MusaiTheme.parchment.withAlpha(50),
                fontSize: 8,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Modular components moved to separate files
