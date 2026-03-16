class Session {
  final int? id;
  final DateTime startTime;
  final DateTime? endTime;
  final String engineVersion;
  final String objective;
  final bool isSynced;

  Session({
    this.id,
    required this.startTime,
    this.endTime,
    this.engineVersion = 'offline',
    this.objective = 'ACTIVE FLOW',
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'engine_version': engineVersion,
      'objective': objective,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory Session.fromMap(Map<String, dynamic> map) {
    return Session(
      id: map['id'] as int?,
      startTime: DateTime.parse(map['start_time'] as String),
      endTime: map['end_time'] != null ? DateTime.parse(map['end_time'] as String) : null,
      engineVersion: map['engine_version'] as String? ?? 'offline',
      objective: map['objective'] as String? ?? 'ACTIVE FLOW',
      isSynced: (map['is_synced'] as int? ?? 0) == 1,
    );
  }

  Session copyWith({
    int? id,
    DateTime? startTime,
    DateTime? endTime,
    String? engineVersion,
    String? objective,
    bool? isSynced,
  }) {
    return Session(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      engineVersion: engineVersion ?? this.engineVersion,
      objective: objective ?? this.objective,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
