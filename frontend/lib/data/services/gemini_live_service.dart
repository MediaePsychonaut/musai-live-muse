import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/audio/audio_recorder.dart';

import '../../core/net/channel_factory.dart';
import '../providers/mentor_providers.dart';

class GeminiLiveService {
  final String apiKey;
  final CortexRecorder recorder;
  final MentorState mentorState;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isDisposed = false;

  static const String _host = 'generativelanguage.googleapis.com';
  static const String _path =
      '/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent';

  // IMMUTABLE Target Model: gemini-2.5-flash-native-audio-latest
  static const String _model = 'models/gemini-2.5-flash-native-audio-latest';

  GeminiLiveService(this.apiKey, this.recorder, this.mentorState);

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
    _isDisposed = false;

    try {
      // Directive: Inject standard headers via ChannelFactory
      _channel = createWebSocketChannel(uri, {
        'X-Goog-Api-Client': 'gl-dart/3.10.8 flutter/stable ai/gemini-live',
        'User-Agent': 'MusAI-Live-Muse/1.0.0 (Android)',
      });

      debugPrint("MUSE_LOG: [EUTE] Auditory Link Established.");

      _subscription = _channel!.stream.listen(
        (data) {
          debugPrint(
            "MUSE_LOG: [EUTE] RAW RECEIVE: Type=${data.runtimeType} | Data=$data",
          );
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
            if (decoded.containsKey('serverContent') ||
                decoded.containsKey('setupComplete')) {
              debugPrint(
                "赤冥蝠_LOG: [INBOUND] EUTE response detected: ${rawString.substring(0, math.min(rawString.length, 50))}...",
              );
            }
            // [SEQUENTIAL-HANDSHAKE] Detect setupComplete (v2.1 CamelCase Spec)
            if (!setupHandled && decoded.containsKey('setupComplete')) {
              debugPrint(
                "MUSE_LOG: [EUTE] Setup Complete Acknowledgement Received.",
              );
              setupHandled = true;
              completer.complete();
            }

            // [AUDITORY-DECODING] Extract and decode 24kHz PCM chunks
            final serverContent = decoded['serverContent'];
            if (serverContent != null) {
              final modelTurn = serverContent['modelTurn'];
              if (modelTurn != null) {
                final parts = modelTurn['parts'] as List?;
                if (parts != null) {
                  for (final part in parts) {
                    // Handle Text Feedback
                    final text = part['text'];
                    if (text != null) {
                      debugPrint("MUSE_LOG: [EUTE] Response: $text");
                    }

                    // Handle Audio Data (PCM 24kHz)
                    final inlineData = part['inlineData'];
                    if (inlineData != null) {
                      final data = inlineData['data'];
                      if (data != null && data is String) {
                        try {
                          final pcmChunk = base64Decode(data);
                          // Directive: Pipe to JitterBuffer (Future)
                          // debugPrint("MUSE_LOG: [EUTE] Decoded PCM Chunk: ${pcmChunk.length} bytes");
                          onMessage({'audio_chunk': pcmChunk});
                        } catch (e) {
                          debugPrint(
                            "MUSE_LOG: [EUTE] Base64 Decode Error: $e",
                          );
                        }
                      }
                    }
                  }
                }
              }
            }

            // Keep existing onMessage trigger for raw payloads if needed
            if (!_isDisposed) {
              onMessage(decoded);
            }
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
          if (!completer.isCompleted) {
            completer.completeError("Connection closed before setup.");
          }
          onDone();
        },
      );

      // [IMMUTABLE HANDSHAKE: THE VOICE OF EUTE]
      try {
        debugPrint("MUSE_LOG: [EUTE] Transmitting System Identity...");
        final handshake = {
          "setup": {
            "model": _model,
            "generationConfig": {
              // <-- FIXED to camelCase
              "responseModalities": ["AUDIO"], // <-- FIXED to UPPERCASE
              "speechConfig": {
                // <-- FIXED to camelCase
                "voiceConfig": {
                  "prebuiltVoiceConfig": {"voiceName": mentorState.voiceName},
                },
              },
            },
            "systemInstruction": {
              // <-- FIXED to camelCase
              "parts": [
                {
                  "text": mentorState.systemInstruction,
                },
              ],
            },
          },
        };
        if (_channel != null && !_isDisposed) {
          _channel!.sink.add(jsonEncode(handshake));
          debugPrint("MUSE_LOG: [EUTE] Sovereign Identity Locked.");
        }
      } catch (handshakeError) {
        // ... existing catch logic
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
    if (_isDisposed) return;
    _isDisposed = true;
    debugPrint("MUSE_LOG: [EUTE] Terminating sync protocols...");
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    debugPrint("MUSE_LOG: [EUTE] System Offline.");
  }

  void sendAudioFrame(Uint8List frame) {
    if (_channel == null) return;
    try {
      // 1. Surgical Mono Downmix with explicit safety
      final processedFrame = _enforceMono(frame);

      // 2. Exact Schema for Gemini Live
      final message = {
        "realtimeInput": {
          "mediaChunks": [
            {
              "mimeType": "audio/pcm;rate=16000",
              "data": base64Encode(processedFrame),
            },
          ],
        },
      };

      if (!_isDisposed) {
        _channel!.sink.add(jsonEncode(message));
      }
    } catch (e, stack) {
      // THIS WILL TELL US WHY IT IS TERMINATING
      debugPrint("MUSE_LOG: [EUTE] PIPELINE_CRASH: $e");
      debugPrint("MUSE_LOG: [EUTE] STACK: $stack");
    }
  }

  Uint8List _enforceMono(Uint8List frame) {
    // If the buffer is already mono-sized (640 bytes for 20ms @ 16kHz)
    if (frame.length <= 640) return frame;

    try {
      final int samples = frame.length ~/ 4; // 2 bytes per sample * 2 channels
      final monoBuffer = Uint8List(samples * 2);

      // Use a more robust view that respects the Uint8List offset
      final data = frame.buffer.asByteData(frame.offsetInBytes, frame.length);
      final output = monoBuffer.buffer.asByteData();

      for (int i = 0; i < samples; i++) {
        // Read L/R 16-bit samples
        int left = data.getInt16(i * 4, Endian.little);
        int right = data.getInt16(i * 4 + 2, Endian.little);

        // Downmix
        int mono = (left + right) ~/ 2;
        output.setInt16(i * 2, mono, Endian.little);
      }
      return monoBuffer;
    } catch (e) {
      debugPrint("MUSE_LOG: [EUTE] MONO_DOWNMIX_ERROR: $e");
      return frame; // Fallback to raw if downmix fails
    }
  }
}
