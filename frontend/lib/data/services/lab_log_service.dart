import 'dart:io';
import 'package:flutter/foundation.dart';

/// [SYNC-LOG-ECHO] LabLogService
/// Persistent telemetry appender for the lab environment.
class LabLogService {
  static final LabLogService _instance = LabLogService._internal();
  factory LabLogService() => _instance;
  LabLogService._internal();

  // Standard Lab Path (Absolute)
  static const String _logPath = r'c:\OPERATIVE_SYSTEM_DER_TAB\02_ACTIVE_PROJECTS\musai-live-muse\docs\LAB_LOG_SESSION.txt';

  /// Appends a telemetry entry to the lab log.
  Future<void> log(String type, String event, {String? metadata}) async {
    final timestamp = DateTime.now().toIso8601String();
    final logLine = '[$timestamp] [$type] $event ${metadata != null ? "| $metadata" : ""}\n';
    
    try {
      // Note: This requires the app to be running on a platform with local FS access (e.g. Windows Desktop)
      final file = File(_logPath);
      // Ensure directory exists if it was deleted
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      await file.writeAsString(logLine, mode: FileMode.append, flush: true);
      debugPrint("MUSE_LOG: [LAB_ECHO] $logLine");
    } catch (e) {
      debugPrint("MUSE_LOG: [LAB_ERROR] Persistent log failure: $e");
    }
  }
}
