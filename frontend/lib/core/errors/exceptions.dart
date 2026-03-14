class SovereignInitializationException implements Exception {
  final String message;
  SovereignInitializationException(this.message);

  @override
  String toString() => message;
}
