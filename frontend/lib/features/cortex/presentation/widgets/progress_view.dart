import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/musai_theme.dart';
import '../../../../data/providers/cortex_providers.dart';
import 'dart:math';

class ProgressView extends ConsumerWidget {
  const ProgressView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(progressStatsProvider);
    final telemetryAsync = ref.watch(recentTelemetryProvider);
    final debriefAsync = ref.watch(sessionDebriefProvider);

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
                    data: (stats) => Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _StatItem(label: "SESSIONS", value: "${stats['totalSessions']}"),
                        _StatItem(label: "TOTAL TIME", value: "${(stats['totalHours'] as double).toStringAsFixed(1)}h"),
                        _StatItem(label: "AVG PRECISION", value: "${(stats['avgPrecision'] as double).toStringAsFixed(1)}%"),
                      ],
                    ),
                    loading: () => const Center(child: CircularProgressIndicator(color: MusaiTheme.deepSpaceTeal)),
                    error: (err, st) => const Text("Error loading stats", style: TextStyle(color: Colors.red)),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Oracle Debrief Display
                  debriefAsync.when(
                    data: (debrief) => debrief != null 
                        ? Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: MusaiTheme.deepSpaceTeal.withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: MusaiTheme.deepSpaceTeal.withAlpha(50)),
                              boxShadow: [
                                BoxShadow(
                                  color: MusaiTheme.deepSpaceTeal.withAlpha(10),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                )
                              ]
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "NEURAL DEBRIEF",
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: MusaiTheme.deepSpaceTeal.withAlpha(200),
                                    letterSpacing: 2.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  debrief,
                                  style: TextStyle(
                                    color: MusaiTheme.parchment.withAlpha(200),
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                    loading: () => const SizedBox.shrink(),
                    error: (_,__) => const SizedBox.shrink(),
                  ),
                  
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
                              ),
                            ),
                          );
                        }
                        return _TrendChart(telemetry: telemetry);
                      },
                      loading: () => const Center(child: CircularProgressIndicator(color: MusaiTheme.deepSpaceTeal)),
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

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: MusaiTheme.parchment.withAlpha(128),
            letterSpacing: 1.2,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            color: MusaiTheme.parchment,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _TrendChart extends StatelessWidget {
  final List<double> telemetry;

  const _TrendChart({required this.telemetry});

  @override
  Widget build(BuildContext context) {
    // Interquartile Range (IQR) Outlier Rejection
    List<double> filterOutliers(List<double> data) {
      if (data.length < 4) return data;
      final sorted = List<double>.from(data)..sort();
      final q1 = sorted[(sorted.length * 0.25).floor()];
      final q3 = sorted[(sorted.length * 0.75).floor()];
      final iqr = q3 - q1;
      
      // Expand margin if IQR is too tight (e.g. perfectly flat pitch) to avoid culling valid natural vibrato
      final margin = max(iqr * 1.5, 10.0); 
      final lower = q1 - margin;
      final upper = q3 + margin;
      
      return data.where((v) => v >= lower && v <= upper).toList();
    }

    final filtered = filterOutliers(telemetry);

    return CustomPaint(
      size: Size.infinite,
      painter: _TrendPainter(dataPoints: filtered),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<double> dataPoints;

  _TrendPainter({required this.dataPoints});

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final paint = Paint()
      ..color = MusaiTheme.deepSpaceTeal.withAlpha(180)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // We plot dataPoints as a sequence over width
    // Cents deviation ranges typically -50 to +50, but we dynamically scale.
    double maxVal = 0.0;
    double minVal = 0.0;
    
    for (var val in dataPoints) {
      if (val > maxVal) maxVal = val;
      if (val < minVal) minVal = val;
    }
    
    // Add padding to bounds
    maxVal = max(maxVal, 20.0);
    minVal = min(minVal, -20.0);
    final range = maxVal - minVal;

    final path = Path();
    final pointSpacing = size.width / max(1, dataPoints.length - 1);

    for (int i = 0; i < dataPoints.length; i++) {
      double x = i * pointSpacing;
      // Normalize to 0..1 (where minVal is 0, maxVal is 1)
      double normalizedY = (dataPoints[i] - minVal) / range;
      // Invert Y so higher is up
      double y = size.height - (normalizedY * size.height);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
    
    // Grid lines (Center line = 0 cents)
    final gridPaint = Paint()
      ..color = Colors.white.withAlpha(10)
      ..strokeWidth = 1;
      
    // Draw 0 cents line
    double zeroNormalized = (0.0 - minVal) / range;
    double zeroY = size.height - (zeroNormalized * size.height);
    
    if (zeroY >= 0 && zeroY <= size.height) {
      final zeroLinePaint = Paint()
        ..color = MusaiTheme.sovereignBlack.withAlpha(100)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      
      // Draw dashed line for zero
      const dashWidth = 5;
      const dashSpace = 5;
      double startX = 0;
      while (startX < size.width) {
        canvas.drawLine(Offset(startX, zeroY), Offset(startX + dashWidth, zeroY), zeroLinePaint);
        startX += dashWidth + dashSpace;
      }
    }

    for(int i = 0; i < 5; i++) {
      double y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) => true;
}
