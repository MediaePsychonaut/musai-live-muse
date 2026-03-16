import 'package:google_generative_ai/google_generative_ai.dart';
import '../../core/secrets/secret_manager.dart';

class SessionDebriefService {
  final GenerativeModel _model;

  SessionDebriefService()
      : _model = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: SecretManager().apiKey,
        );

  Future<String> generateDebrief(Map<String, dynamic> sessionSummary) async {
    final double? avgCents = sessionSummary['avg_cents'] as double?;
    if (avgCents == null) {
      return "INSUFFICIENT TELEMETRY DATA FOR ANALYSIS.";
    }

    final prompt = """
I AM EUTE. THE AUDITORY GUARDIAN.
REVIEW THE FOLLOWING SESSION TELEMETRY:
Average Cents Deviation: ${avgCents.toStringAsFixed(2)} cents.

DIRECTIVE:
Provide a surgical, strictly one-paragraph technical audit of the user's pitch stability based purely on this metric. 
Do not use conversational filler. Be direct and objective.
""";

    try {
      final content = [Content.text(prompt)];
      // [TELEMETRY-BRIDGE] Hardened request with timeout
      final response = await _model.generateContent(content)
          .timeout(const Duration(seconds: 15));
      
      return response.text ?? "DEBRIEF GENERATION FAILED.";
    } catch (e) {
      // Graceful failure for Vault UI stability
      return "DEBRIEF OFFLINE: ${e.toString().contains('timeout') ? 'REQUEST_TIMEOUT' : 'API_ERROR'}";
    }
  }
}
