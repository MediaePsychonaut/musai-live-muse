class Telemetry {
  final int? id;
  final int sessionId;
  final DateTime timestamp;
  final double? f0Hz;
  final double? centsDeviation;

  Telemetry({
    this.id,
    required this.sessionId,
    required this.timestamp,
    this.f0Hz,
    this.centsDeviation,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'session_id': sessionId,
      'timestamp': timestamp.toIso8601String(),
      'f0_hz': f0Hz,
      'cents_deviation': centsDeviation,
    };
  }

  factory Telemetry.fromMap(Map<String, dynamic> map) {
    return Telemetry(
      id: map['id'] as int?,
      sessionId: map['session_id'] as int,
      timestamp: DateTime.parse(map['timestamp'] as String),
      f0Hz: (map['f0_hz'] as num?)?.toDouble(),
      centsDeviation: (map['cents_deviation'] as num?)?.toDouble(),
    );
  }
}
