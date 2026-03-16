import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// [MOBILE-LOG-REPAIR] LabLogService
/// Persistent telemetry appender with dynamic path resolution for Mobile/Desktop.
class LabLogService {
  static final LabLogService _instance = LabLogService._internal();
  factory LabLogService() => _instance;
  LabLogService._internal();

  String? _resolvedPath;

  Future<String?> _getLogPath() async {
    if (_resolvedPath != null) return _resolvedPath;

    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final directory = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
        _resolvedPath = p.join(directory.path, 'LAB_LOG_SESSION.txt');
      } else if (Platform.isWindows) {
        // Standard Lab Path for Windows/Desktop
        _resolvedPath = r'c:\OPERATIVE_SYSTEM_DER_TAB\02_ACTIVE_PROJECTS\musai-live-muse\docs\LAB_LOG_SESSION.txt';
      }
    } catch (e) {
      debugPrint("MUSE_LOG: [LAB_ERROR] Path resolution failed: $e");
    }
    return _resolvedPath;
  }

  /// Appends a telemetry entry to the lab log.
  Future<void> log(String type, String event, {String? metadata}) async {
    final timestamp = DateTime.now().toIso8601String();
    final logLine = '[$timestamp] [$type] $event ${metadata != null ? "| $metadata" : ""}\n';
    
    // Always ECHO to terminal for capture [UI-AUDIT-ZENITH]
    debugPrint("MUSE_LAB_ECHO: $logLine");

    try {
      final path = await _getLogPath();
      if (path == null) return;
      
      final file = File(path);
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      await file.writeAsString(logLine, mode: FileMode.append, flush: true);
    } catch (e) {
      // Internal silent failure, we still have the terminal echo
    }
  }
}
