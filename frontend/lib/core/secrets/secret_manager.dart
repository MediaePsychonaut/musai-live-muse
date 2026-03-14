import '../errors/exceptions.dart';

class SecretManager {
  SecretManager._internal();
  static final SecretManager _instance = SecretManager._internal();
  factory SecretManager() => _instance;

  static const String _envKey = 'GEMINI_API_KEY';

  String get apiKey {
    const key = String.fromEnvironment(_envKey);
    if (key.isEmpty) {
      throw SovereignInitializationException(
        "CRITICAL: GEMINI_API_KEY not found. Build must include --dart-define=GEMINI_API_KEY=your_key",
      );
    }
    return key;
  }
}
