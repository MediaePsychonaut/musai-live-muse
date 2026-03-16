import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../local/database_helper.dart';
import '../models/session.dart';
import '../models/telemetry.dart';

class PracticeLedger {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Create a new session and return the assigned session ID
  Future<int> startSession({
    String engineVersion = 'offline',
    String objective = 'ACTIVE FLOW',
  }) async {
    final db = await _dbHelper.database;
    final session = Session(
      startTime: DateTime.now(),
      engineVersion: engineVersion,
      objective: objective,
    );
    return await db.insert('sessions', session.toMap());
  }

  // Close the session and synchronize with Firestore
  Future<int> endSession(int sessionId) async {
    final db = await _dbHelper.database;
    final endTime = DateTime.now().toIso8601String();
    
    // Retrieve session telemetry averages
    final result = await db.rawQuery('''
      SELECT 
        AVG(f0_hz) as avg_f0,
        AVG(ABS(cents_deviation)) as avg_cents
      FROM telemetry
      WHERE session_id = ?
    ''', [sessionId]);

    // Retrieve initial session data
    final sessionData = await db.query('sessions', where: 'id = ?', whereArgs: [sessionId]);
    if (sessionData.isEmpty) return 0;
    
    final startTimeStr = sessionData.first['start_time'] as String;
    final engineVersion = sessionData.first['engine_version'] as String? ?? 'unknown';
    final objective = sessionData.first['objective'] as String? ?? 'ACTIVE FLOW';
    
    final startTime = DateTime.parse(startTimeStr);
    final durationSecs = DateTime.parse(endTime).difference(startTime).inSeconds;
    
    double avgF0 = 0.0;
    double avgCents = 0.0;
    if (result.isNotEmpty && result.first['avg_cents'] != null) {
      avgF0 = result.first['avg_f0'] as double;
      avgCents = result.first['avg_cents'] as double;
    }

    final summaryMap = {
      'session_id': sessionId,
      'timestamp': endTime,
      'duration_seconds': durationSecs,
      'avg_f0': avgF0,
      'avg_cents': avgCents,
      'engine_version': engineVersion,
      'objective': objective,
    };

    int isSynced = 0;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc('default_user')
          .collection('sessions')
          .add(summaryMap);
      isSynced = 1;
    } on FirebaseException catch (e) {
      debugPrint("MUSE_LOG: Firestore Sync Failed (Offline Rebound Active). Error: ${e.message}");
    } catch (e) {
      debugPrint("MUSE_LOG: Unexpected sync error. ${e.toString()}");
    }

    return await db.update(
      'sessions',
      {
        'end_time': endTime,
        'is_synced': isSynced,
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  // Retry pending uploads
  Future<void> syncPendingSessions() async {
    final db = await _dbHelper.database;
    final pending = await db.query(
      'sessions', 
      where: 'is_synced = 0 AND end_time IS NOT NULL'
    );
    
    for (final row in pending) {
      final sessionId = row['id'] as int;
      final startTimeStr = row['start_time'] as String;
      final endTimeStr = row['end_time'] as String;
      final engineVer = row['engine_version'] as String? ?? 'unknown';
      final objective = row['objective'] as String? ?? 'ACTIVE FLOW';
      
      final durationSecs = DateTime.parse(endTimeStr).difference(DateTime.parse(startTimeStr)).inSeconds;
      
      final result = await db.rawQuery('''
        SELECT 
          AVG(f0_hz) as avg_f0,
          AVG(ABS(cents_deviation)) as avg_cents
        FROM telemetry
        WHERE session_id = ?
      ''', [sessionId]);
      
      double avgF0 = 0.0;
      double avgCents = 0.0;
      if (result.isNotEmpty && result.first['avg_cents'] != null) {
        avgF0 = result.first['avg_f0'] as double;
        avgCents = result.first['avg_cents'] as double;
      }
      
      try {
        await FirebaseFirestore.instance
          .collection('users')
          .doc('default_user')
          .collection('sessions')
          .add({
            'session_id': sessionId,
            'timestamp': endTimeStr,
            'duration_seconds': durationSecs,
            'avg_f0': avgF0,
            'avg_cents': avgCents,
            'engine_version': engineVer,
            'objective': objective,
          });
          
        await db.update('sessions', {'is_synced': 1}, where: 'id = ?', whereArgs: [sessionId]);
      } on FirebaseException catch (_) {
        // Break network retries upon initial connectivity failure
        break;
      } catch (_) {
        break;
      }
    }
  }

  // Log a telemetry point if inside an active session
  Future<void> logTelemetry(int sessionId, double f0, double centsDeviation) async {
    final db = await _dbHelper.database;
    final telemetry = Telemetry(
      sessionId: sessionId,
      timestamp: DateTime.now(),
      f0Hz: f0,
      centsDeviation: centsDeviation,
    );
    await db.insert('telemetry', telemetry.toMap());
  }

  // Calculate moving averages or weak points for the previous session (Priming constraint)
  Future<Map<String, dynamic>?> getLastSessionSummary() async {
    final db = await _dbHelper.database;
    
    // Get the most recent ended session
    final List<Map<String, dynamic>> sessions = await db.query(
      'sessions',
      orderBy: 'start_time DESC',
      limit: 1,
    );

    if (sessions.isEmpty) return null;

    final sessionId = sessions.first['id'] as int;
    
    // Query telemetry for this session
    final result = await db.rawQuery('''
      SELECT 
        AVG(f0_hz) as avg_f0,
        AVG(ABS(cents_deviation)) as avg_cents
      FROM telemetry
      WHERE session_id = ?
    ''', [sessionId]);

    if (result.isNotEmpty && result.first['avg_cents'] != null) {
      return {
        'session_id': sessionId,
        'avg_f0': result.first['avg_f0'],
        'avg_cents': result.first['avg_cents']
      };
    }
    
    return null;
  }

  // Get global stats for the Progress Vault
  Future<Map<String, dynamic>> getProgressStats() async {
    final db = await _dbHelper.database;
    final sessions = await db.query('sessions', where: 'end_time IS NOT NULL');
    
    int totalSessions = sessions.length;
    double totalHours = 0.0;
    
    for (var s in sessions) {
      if (s['start_time'] != null && s['end_time'] != null) {
        final start = DateTime.parse(s['start_time'] as String);
        final end = DateTime.parse(s['end_time'] as String);
        final diff = end.difference(start).inSeconds;
        if (diff > 0) {
          totalHours += diff / 3600.0;
        }
      }
    }

    final telemetry = await db.rawQuery('SELECT AVG(ABS(cents_deviation)) as global_cents FROM telemetry');
    double avgPrecision = 0.0; 
    if (telemetry.isNotEmpty && telemetry.first['global_cents'] != null) {
      double avgCents = (telemetry.first['global_cents'] as num).toDouble();
      // 50 cents = 0% precision. Tighten/loosen here as needed.
      // We'll use a smoother mapping: 100% at 0 cents, 50% at 25 cents, 0% at 50+ cents.
      avgPrecision = (1.0 - (avgCents / 50.0)).clamp(0.0, 1.0) * 100.0;
    } else {
      // If no telemetry but session exists, assume 100% or "N/A"
      avgPrecision = 100.0; 
    }

    return {
      'totalSessions': totalSessions,
      'totalHours': totalHours,
      'avgPrecision': avgPrecision,
    };
  }

  // Get cents deviation timeline for the most recent session
  Future<List<double>> getRecentSessionTelemetry() async {
    final db = await _dbHelper.database;
    final sessions = await db.query('sessions', orderBy: 'start_time DESC', limit: 1);
    if (sessions.isEmpty) return [];

    final sessionId = sessions.first['id'] as int;
    final rows = await db.query(
      'telemetry',
      columns: ['cents_deviation'],
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC'
    );

    return rows.map((r) => (r['cents_deviation'] as num).toDouble()).toList();
  }
}
