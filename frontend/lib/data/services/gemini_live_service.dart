import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/audio/audio_recorder.dart';
import '../../core/net/channel_factory.dart';
import '../providers/mentor_providers.dart';
import '../providers/engine_provider.dart';
import '../../core/audio/pulse_engine.dart';
import '../../core/audio/audio_output_service.dart';

class GeminiLiveService {
  final String apiKey;
  final CortexRecorder recorder;
  final MentorState mentorState;
  final EngineType engineType;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isDisposed = false;

  static const String _host = 'generativelanguage.googleapis.com';

  String get _path {
    return engineType == EngineType.flash20Exp
        ? '/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent'
        : '/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent';
  }

  String get _model {
    return engineType == EngineType.flash20Exp
        ? 'models/gemini-2.0-flash-exp'
        : 'models/gemini-2.5-flash-native-audio-latest';
  }

  GeminiLiveService(this.apiKey, this.recorder, this.mentorState, this.engineType);

  bool get isConnected => _channel != null;

  Future<void> connect({
    required Function(Map<String, dynamic>) onMessage,
    required Function(Object) onError,
    required Function() onDone,
    Function(String name, Map<String, dynamic> args)? onHardwareCommand,
  }) async {
    debugPrint("MUSE_LOG: [EUTE] Initializing high-fidelity audio sync...");

    final uri = Uri.parse('wss://$_host$_path?key=$apiKey');
    final completer = Completer<void>();
    bool setupHandled = false;
    _isDisposed = false;

    try {
      _channel = createWebSocketChannel(uri, {
        'X-Goog-Api-Client': 'gl-dart/3.10.8 flutter/stable ai/gemini-live',
        'User-Agent': 'MusAI-Live-Muse/1.0.0 (Android)',
      });

      debugPrint("MUSE_LOG: [EUTE] Auditory Link Established.");

      _subscription = _channel!.stream.listen(
        (data) {
          if (data is String) {
            debugPrint("MUSE_TELEMETRY: [WS] RAW RECEIVE: Type=String | Length=${data.length}");
          } else if (data is Uint8List) {
            debugPrint("MUSE_TELEMETRY: [WS] RAW RECEIVE: Type=Uint8List | Length=${data.length}");
          }
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
            if (decoded.containsKey('server_content') ||
                decoded.containsKey('setup_complete') ||
                decoded.containsKey('serverContent') ||
                decoded.containsKey('setupComplete')) {
              _logServerContent(decoded);
            }
            // [SEQUENTIAL-HANDSHAKE] Detect setupComplete
            if (!setupHandled && (decoded.containsKey('setup_complete') || decoded.containsKey('setupComplete'))) {
              debugPrint(
                "MUSE_LOG: [EUTE] Setup Complete Acknowledgement Received.",
              );
              setupHandled = true;
              completer.complete();
            }

            // [AUDITORY-DECODING] Extract and decode 24kHz PCM chunks
            final serverContent = decoded['server_content'] ?? decoded['serverContent'];
            if (serverContent != null) {
              final modelTurn = serverContent['model_turn'] ?? serverContent['modelTurn'];
              if (modelTurn != null) {
                final parts = modelTurn['parts'] as List?;
                if (parts != null) {
                  for (final part in parts) {
                    final functionCall = part['function_call'] ?? part['functionCall'];
                    if (functionCall != null) {
                      _handleFunctionCall(functionCall, onHardwareCommand);
                    }

                    final inlineData = part['inline_data'] ?? part['inlineData'];
                    if (inlineData != null) {
                      final data = inlineData['data'];
                      if (data != null && data is String) {
                        try {
                          final pcmChunk = base64Decode(data);
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
        
        final Map<String, dynamic> handshake;

        if (engineType == EngineType.flash20Exp) {
          handshake = {
            "setup": {
              "model": _model,
              "generation_config": {
                "response_modalities": ["audio"],
                "speech_config": {
                  "voice_config": {
                    "prebuilt_voice_config": {"voice_name": mentorState.voiceName},
                  },
                },
              },
              "system_instruction": {
                "parts": [
                  {
                    "text": mentorState.systemInstruction,
                  },
                ],
              },
              "tools": [
                {
                  "function_declarations": [
                    {
                      "name": "set_metronome",
                      "description": "Starts or stops the native metronome pulse.",
                      "parameters": {
                        "type": "OBJECT",
                        "properties": {
                          "bpm": {
                            "type": "NUMBER",
                            "description": "The desired Beats Per Minute (BPM)"
                          },
                          "signature": {
                            "type": "INTEGER",
                            "description": "The time signature numerator (e.g., 4 for 4/4 time)"
                          },
                          "active": {
                            "type": "BOOLEAN",
                            "description": "True to start the metronome, False to stop it"
                          }
                        },
                        "required": ["bpm", "active"]
                      }
                    },
                    {
                      "name": "set_drone",
                      "description": "Starts or stops the native background drone synthesizer.",
                      "parameters": {
                        "type": "OBJECT",
                        "properties": {
                          "frequency": {
                            "type": "NUMBER",
                            "description": "The target drone frequency in Hz"
                          },
                          "active": {
                            "type": "BOOLEAN",
                            "description": "True to start the drone, False to stop it"
                          }
                        },
                        "required": ["frequency", "active"]
                      }
                    },
                    {
                      "name": "start_practice_session",
                      "description": "Initializes a structured practice session with a specific name and focus.",
                      "parameters": {
                        "type": "OBJECT",
                        "properties": {
                          "name": {
                            "type": "STRING",
                            "description": "The title or name of the practice session"
                          },
                          "focus": {
                            "type": "STRING",
                            "description": "The technical focus of the session"
                          }
                        },
                        "required": ["name", "focus"]
                      }
                    },
                    {
                      "name": "stop_practice_session",
                      "description": "Finalizes the current practice session.",
                      "parameters": {
                        "type": "OBJECT",
                        "properties": {}
                      }
                    }
                  ]
                }
              ]
            },
          };
        } else {
          handshake = {
            "setup": {
              "model": _model,
              "generationConfig": {
                "responseModalities": ["AUDIO"],
                "speechConfig": {
                  "voiceConfig": {
                    "prebuiltVoiceConfig": {"voiceName": mentorState.voiceName},
                  },
                },
              },
              "systemInstruction": {
                "parts": [
                  {
                    "text": mentorState.systemInstruction,
                  },
                ],
              },
              "tools": [
                {
                  "functionDeclarations": [
                    {
                      "name": "set_metronome",
                      "description": "Starts or stops the native metronome pulse.",
                      "parameters": {
                        "type": "OBJECT",
                        "properties": {
                          "bpm": {
                            "type": "NUMBER",
                            "description": "The desired Beats Per Minute (BPM)"
                          },
                          "signature": {
                            "type": "INTEGER",
                            "description": "The time signature numerator (e.g., 4 for 4/4 time)"
                          },
                          "active": {
                            "type": "BOOLEAN",
                            "description": "True to start the metronome, False to stop it"
                          }
                        },
                        "required": ["bpm", "active"]
                      }
                    },
                    {
                      "name": "set_drone",
                      "description": "Starts or stops the native background drone synthesizer.",
                      "parameters": {
                        "type": "OBJECT",
                        "properties": {
                          "frequency": {
                            "type": "NUMBER",
                            "description": "The target drone frequency in Hz"
                          },
                          "active": {
                            "type": "BOOLEAN",
                            "description": "True to start the drone, False to stop it"
                          }
                        },
                        "required": ["frequency", "active"]
                      }
                    },
                    {
                      "name": "start_practice_session",
                      "description": "Initializes a structured practice session with a specific name and focus.",
                      "parameters": {
                        "type": "OBJECT",
                        "properties": {
                          "name": {
                            "type": "STRING",
                            "description": "The title or name of the practice session"
                          },
                          "focus": {
                            "type": "STRING",
                            "description": "The technical focus of the session"
                          }
                        },
                        "required": ["name", "focus"]
                      }
                    },
                    {
                      "name": "stop_practice_session",
                      "description": "Finalizes the current practice session.",
                      "parameters": {
                        "type": "OBJECT",
                        "properties": {}
                      }
                    }
                  ]
                }
              ]
            },
          };
        }

        if (_channel != null && !_isDisposed) {
          _channel!.sink.add(jsonEncode(handshake));
          debugPrint("MUSE_LOG: [EUTE] Sovereign Identity Locked. Engine: $_model");
        }
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
    if (_isDisposed) return;
    _isDisposed = true;
    debugPrint("MUSE_LOG: [EUTE] Terminating sync protocols...");
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    debugPrint("MUSE_LOG: [EUTE] System Offline.");
  }

  void sendAudioFrame(Uint8List frame, {String? metadata}) {
    if (_channel == null) return;
    try {
      // 1. Surgical Mono Downmix with explicit safety
      final processedFrame = _enforceMono(frame);

      // 2. Exact Schema for Gemini Live
      final Map<String, dynamic> message;
      
      if (engineType == EngineType.flash20Exp) {
        // [METADATA-INJECTION] Send numerical truth bridge to AI
        if (metadata != null) {
          final metadataMsg = {
            "client_content": {
              "turns": [
                {
                  "role": "user",
                  "parts": [
                    {
                      "text": metadata
                    }
                  ]
                }
              ],
              "turn_complete": false
            }
          };
          if (!_isDisposed) {
            _channel!.sink.add(jsonEncode(metadataMsg));
          }
        }

        message = {
          "realtime_input": {
            "media_chunks": [
              {
                "mime_type": "audio/pcm;rate=16000",
                "data": base64Encode(processedFrame),
              },
            ],
          },
        };
      } else {
        // [METADATA-INJECTION] CamelCase format
        if (metadata != null) {
          final metadataMsg = {
            "clientContent": {
              "turns": [
                {
                  "role": "user",
                  "parts": [
                    {
                      "text": metadata
                    }
                  ]
                }
              ],
              "turnComplete": false
            }
          };
          if (!_isDisposed) {
            _channel!.sink.add(jsonEncode(metadataMsg));
          }
        }

        message = {
          "realtimeInput": {
            "mediaChunks": [
              {
                "mimeType": "audio/pcm;rate=16000",
                "data": base64Encode(processedFrame),
              },
            ],
          },
        };
      }

      if (!_isDisposed) {
        _channel!.sink.add(jsonEncode(message));
      }
    } catch (e, stack) {
      debugPrint("MUSE_LOG: [EUTE] PIPELINE_CRASH: $e");
      debugPrint("MUSE_LOG: [EUTE] STACK: $stack");
    }
  }

  Uint8List _enforceMono(Uint8List frame) {
    if (frame.length <= 640) return frame;

    try {
      final int samples = frame.length ~/ 4;
      final monoBuffer = Uint8List(samples * 2);

      final data = frame.buffer.asByteData(frame.offsetInBytes, frame.length);
      final output = monoBuffer.buffer.asByteData();

      for (int i = 0; i < samples; i++) {
        int left = data.getInt16(i * 4, Endian.little);
        int right = data.getInt16(i * 4 + 2, Endian.little);

        int mono = (left + right) ~/ 2;
        output.setInt16(i * 2, mono, Endian.little);
      }
      return monoBuffer;
    } catch (e) {
      debugPrint("MUSE_LOG: [EUTE] MONO_DOWNMIX_ERROR: $e");
      return frame;
    }
  }

  void _logServerContent(Map<String, dynamic> decoded) {
    if (decoded.containsKey('setup_complete') || decoded.containsKey('setupComplete')) {
      debugPrint("MUSE_TELEMETRY: [SETUP] Acknowledgement Received.");
      return;
    }
    
    final serverContent = decoded['server_content'] ?? decoded['serverContent'];
    if (serverContent != null) {
      final modelTurn = serverContent['model_turn'] ?? serverContent['modelTurn'];
      if (modelTurn != null) {
        // [STABILIZATION] Purge buffer ONLY on a fresh model turn start
        debugPrint("MUSE_LOG: [EUTE] model_turn detected. Purging vocal buffer for fresh response.");
        AudioOutputService().clearVocalBuffer();
        
        final parts = modelTurn['parts'] as List?;
        if (parts != null) {
          for (final part in parts) {
            final text = part['text'];
            if (text != null) {
              debugPrint("MUSE_TELEMETRY: [TEXT] $text");
            }
            final inlineData = part['inline_data'] ?? part['inlineData'];
            if (inlineData != null) {
              final data = inlineData['data'];
              if (data is String) {
                final byteLength = (data.length * 3) ~/ 4;
                debugPrint("MUSE_TELEMETRY: [AUDIO] Received $byteLength bytes");
              }
            }
          }
        }
      }
    }
  }

  void _handleFunctionCall(Map<String, dynamic> functionCall, Function(String name, Map<String, dynamic> args)? onHardwareCommand) {
    if (_isDisposed) return;
    final name = functionCall['name'];
    final id = functionCall['id']; // ID handles async mappings
    final args = functionCall['args'] as Map<String, dynamic>;

    debugPrint("MUSE_LOG: [EUTE] Function Call Triggered: $name(args: $args)");

    final pulseEngine = PulseEngine();
    
    // Notify UI (Sensory Sync)
    onHardwareCommand?.call(name, args);
    
    Map<String, dynamic> responsePayload = {
      "result": "success"
    };

    if (name == 'set_metronome' || name == 'set_drone' || name == 'start_practice_session' || name == 'stop_practice_session') {
      // Logic handled via onHardwareCommand callback to ensure Provider Sync
    } else {
      responsePayload = {"result": "error", "message": "Unknown function"};
    }

    final bool isExp = engineType == EngineType.flash20Exp;
    final Map<String, dynamic> functionResponseMsg;
    
    final responsePart = isExp ? {
      "function_response": {
        "name": name,
        if (id != null) "id": id,
        "response": responsePayload
      }
    } : {
      "functionResponse": {
        "name": name,
        if (id != null) "id": id,
        "response": responsePayload
      }
    };

    if (isExp) {
      functionResponseMsg = {
        "client_content": {
          "turns": [
            {
              "role": "user",
              "parts": [responsePart]
            }
          ],
          "turn_complete": true
        }
      };
    } else {
      functionResponseMsg = {
        "clientContent": {
          "turns": [
            {
              "role": "user",
              "parts": [responsePart]
            }
          ],
          "turnComplete": true
        }
      };
    }
    
    if (_channel != null && !_isDisposed) {
      try {
        _channel!.sink.add(jsonEncode(functionResponseMsg));
      } catch (e) {
        debugPrint("MUSE_LOG: [EUTE] Sink Add Error (Function Response): $e");
      }
    }
  }
}
