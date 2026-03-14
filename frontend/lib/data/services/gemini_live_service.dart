import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/audio/audio_recorder.dart';

import '../../core/net/channel_factory.dart';

class GeminiLiveService {
  final String apiKey;
  final CortexRecorder recorder;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  static const String _host = 'generativelanguage.googleapis.com';
  static const String _path =
      '/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent';

  // IMMUTABLE Target Model: gemini-2.5-flash-native-audio-latest
  static const String _model = 'models/gemini-2.5-flash-native-audio-latest';

  GeminiLiveService(this.apiKey, this.recorder);

  bool get isConnected => _channel != null;

  Future<void> connect({
    required Function(Map<String, dynamic>) onMessage,
    required Function(Object) onError,
    required Function() onDone,
  }) async {
    debugPrint("MUSE_LOG: [EUTE] Initializing high-fidelity audio sync...");

    final uri = Uri.parse('wss://$_host$_path?key=$apiKey');
    final completer = Completer<void>();
    bool setupHandled = false;

    try {
      // Directive: Inject standard headers via ChannelFactory
      _channel = createWebSocketChannel(uri, {
        'X-Goog-Api-Client': 'gl-dart/3.10.8 flutter/stable ai/gemini-live',
        'User-Agent': 'MusAI-Live-Muse/1.0.0 (Android)',
      });

      debugPrint("MUSE_LOG: [EUTE] Auditory Link Established.");

      _subscription = _channel!.stream.listen(
        (data) {
          /*debugPrint(
            "MUSE_LOG: [EUTE] RAW RECEIVE: Type=${data.runtimeType} | Data=$data",
          );*/
          String? rawString;
          try {
            if (data is Uint8List) {
              rawString = utf8.decode(data);
            } else if (data is String) {
              rawString = data;
            } else {
              throw FormatException(
                "Unsupported WebSocket data type: ${data.runtimeType}",
              );
            }

            final decoded = jsonDecode(rawString);

            // [SEQUENTIAL-HANDSHAKE] Detect setupComplete (CamelCase from Google)
            final isSetup = rawString.contains('setupComplete');
            if (!setupHandled && isSetup) {
              debugPrint("MUSE_LOG: [EUTE] Setup Complete Received: $decoded");
              setupHandled = true;
              completer.complete();
            }

            // Directive: Check for model_turn and handle response
            onMessage(decoded);
          } catch (e) {
            debugPrint("MUSE_LOG: [EUTE] Stream Parse Error: $e");
            debugPrint(
              "MUSE_LOG: [EUTE] Raw Data Fragment: ${rawString ?? data.toString().substring(0, math.min(data.toString().length, 100))}",
            );
          }
        },
        onError: (error) {
          debugPrint("MUSE_LOG: [EUTE] LINK_SEVERED: $error");
          if (!completer.isCompleted) completer.completeError(error);
          onError(error);
        },
        onDone: () {
          debugPrint(
            "MUSE_LOG: [EUTE] Session Purged. CLOSE_CODE: ${_channel?.closeCode}",
          );
          _channel = null;
          if (!completer.isCompleted)
            completer.completeError("Connection closed before setup.");
          onDone();
        },
      );

      // [IMMUTABLE HANDSHAKE: THE VOICE OF EUTE]
      try {
        debugPrint("MUSE_LOG: [EUTE] Transmitting System Identity...");
        final handshake = {
          "setup": {
            "model": _model,
            "generation_config": {
              "response_modalities": ["audio"],
              "speech_config": {
                "voice_config": {
                  "prebuilt_voice_config": {"voice_name": "puck"},
                },
              },
            },
            "system_instruction": {
              "parts": [
                {
                  "text":
                      "I am EUTE. The Auditory Guardian of MusAI. Technical, precise, and minimalist. Always start with: 'I am EUTE. The sync is locked.'",
                },
              ],
            },
          },
        };
        /**
        final handshake = {
          "setup": {
            "model": _model,
            "generation_config": {
              //"response_modalities": ["audio"],
              "responseModalities": [
                "audio",
              ], //quick test to check that _ separator is not a problem
              "speech_config": {
                "voice_config": {
                  "prebuilt_voice_config": {
                    //"voice_name": "aoede" // High-fidelity technical Muse
                    "voice_name":
                        "puck", // Testing if aoede is not part of the problem 1007
                  },
                },
              },
            },
            //"audio_config": {"sample_rate": 16000},
            "system_instruction": {
              "parts": [
                {
                  "text":
                      "I am EUTE. The Auditory Guardian of MusAI. Neon-Technical, precise, corrective, and minimalist. I analyze the Chief Architect's violin performance (pitch/tempo) and provide technical, data-driven feedback focusing on the 'Physics' of the music. ALWAYS start the session with: 'I am EUTE. The sync is locked. Let us begin the technical audit.'",
                },
              ],
            },
          },
        };
        **/
        _channel!.sink.add(jsonEncode(handshake));
        debugPrint("MUSE_LOG: [EUTE] Sovereign Identity Locked.");
      } catch (handshakeError) {
        debugPrint("MUSE_LOG: [EUTE] HANDSHAKE_FAILURE: $handshakeError");
        if (!completer.isCompleted) completer.completeError(handshakeError);
        rethrow;
      }
    } catch (e) {
      debugPrint("MUSE_LOG: [EUTE] CONNECTION_DENIED: $e");
      if (!completer.isCompleted) completer.completeError(e);
      onError(e);
      rethrow;
    }

    return completer.future;
  }

  void disconnect() {
    debugPrint("MUSE_LOG: [EUTE] Terminating sync protocols...");
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    debugPrint("MUSE_LOG: [EUTE] System Offline.");
  }

  void sendAudioFrame(Uint8List frame) {
    if (_channel == null) return;

    final message = {
      "realtime_input": {
        "media_chunks": [
          {"mime_type": "audio/pcm;rate=16000", "data": base64Encode(frame)},
        ],
      },
    };

    _channel!.sink.add(jsonEncode(message));
  }
}
