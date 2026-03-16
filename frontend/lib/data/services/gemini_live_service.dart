import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/audio/audio_recorder.dart';
import '../../core/net/channel_factory.dart';
import '../providers/mentor_providers.dart';
import '../providers/engine_provider.dart';
import '../../core/audio/audio_output_service.dart';
import '../services/lab_log_service.dart';

class GeminiLiveService {
  final String apiKey;
  final CortexRecorder recorder;
  final MentorState mentorState;
  final EngineType engineType;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isDisposed = false;
  bool _isTurnActive = false; // Surgical Turn Flag
  
  // High-Fidelity Telemetry Accessors
  double lastVolume = 0.0;
  double lastPitch = 0.0;
  List<double> lastSpectrum = const [];
  double lastResonance = 0.0;
  double lastAiResonance = 0.0;
  double lastEuteAmplitude = 0.0;
  int lastPulseTick = 0;
  double lastCentsDeviation = 0.0;
  
  // [PROTOCOL-GUARDIAN] Tool-Call Buffering
  final List<Map<String, dynamic>> _pendingToolResponses = [];

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
            if (decoded == null) return;

            // [ROOT-TOOL-CALLS] Detect tool calls at the root level (List iteration)
            final toolCall = decoded['tool_call'] ?? decoded['toolCall'];
            if (toolCall != null) {
              final calls = toolCall['function_calls'] ?? toolCall['functionCalls'];
              if (calls is List) {
                _handleFunctionCalls(calls, onHardwareCommand);
              } else {
                _handleFunctionCalls([toolCall], onHardwareCommand);
              }
            }

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
              // Parse Telemetry if present (System Bridge)
              lastResonance = serverContent['resonance'] ?? lastResonance;
              lastEuteAmplitude = serverContent['eute_amplitude'] ?? lastEuteAmplitude;

              final modelTurn = serverContent['model_turn'] ?? serverContent['modelTurn'];
              if (modelTurn != null) {
                final parts = modelTurn['parts'] as List?;
                if (parts != null) {
                  final List<dynamic> batchCalls = [];
                  for (final part in parts) {
                    final functionCall = part['function_call'] ?? part['functionCall'];
                    if (functionCall != null) {
                      batchCalls.add(functionCall);
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
                  if (batchCalls.isNotEmpty) {
                    _handleFunctionCalls(batchCalls, onHardwareCommand);
                  }
                }
              }
            }

            // [TURN-COMPLETION] Detect turn_complete to reset state and dispatch tools
            if (serverContent != null) {
              final bool turnComplete = serverContent['turn_complete'] ?? serverContent['turnComplete'] ?? false;
              if (turnComplete) {
                debugPrint("MUSE_LOG: [EUTE] model_turn_complete detected. Resetting turn flag.");
                _isTurnActive = false;
                _dispatchPendingToolResponses(); // [PROTOCOL-GUARDIAN]
                AudioOutputService().stopVocalStream(); // Close stream if no pulse/drone
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
    AudioOutputService().stopVocalStream();
    debugPrint("MUSE_LOG: [EUTE] System Offline.");
  }

  void sendAudioFrame(Uint8List frame, {String? metadata}) {
    if (_channel == null) return;
    
    // [BARGE-IN-DETECTION] Calculate RMS for intelligent purge
    final double rms = _calculateRMS(frame);
    if (rms > 0.05) {
      if (_isTurnActive) {
        debugPrint("MUSE_LOG: [EUTE] BARGE-IN DETECTED (RMS: ${rms.toStringAsFixed(3)}). Purging vocal buffer.");
        AudioOutputService().clearVocalBuffer();
        _isTurnActive = false;
      }
    }

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
        // [METADATA-INJECTION] Consistent snake_case
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
        // [STABILIZATION] Purge buffer with a 100ms drain delay to prevent audio shredding
        if (!_isTurnActive) {
          debugPrint("MUSE_LOG: [EUTE] model_turn detected. Draining remaining audio buffer...");
          _isTurnActive = true;
          Future.delayed(const Duration(milliseconds: 100), () {
             debugPrint("MUSE_LOG: [EUTE] Drain complete. Purging vocal buffer for fresh response.");
             AudioOutputService().clearVocalBuffer();
          });
        }
        
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

  void _handleFunctionCalls(List<dynamic> calls, Function(String name, Map<String, dynamic> args)? onHardwareCommand) {
    if (_isDisposed || calls.isEmpty) return;

    final List<Map<String, dynamic>> responseParts = [];

    for (var callData in calls) {
      final Map<String, dynamic> functionCall = callData as Map<String, dynamic>;
      final name = functionCall['name'] ?? functionCall['function_name'];
      final id = functionCall['id'] ?? functionCall['call_id']; 
      final args = functionCall['args'] as Map<String, dynamic>? ?? {};

      debugPrint("MUSE_LOG: [EUTE] Protocol Anchor: Executing $name(args: $args)");
      LabLogService().log("TOOL_EXEC", name, metadata: args.toString());

      // Notify UI (Sensory Sync)
      onHardwareCommand?.call(name, args);
      
      Map<String, dynamic> responsePayload = {
        "result": "success"
      };

      if (name == 'set_metronome' || name == 'set_drone' || name == 'start_practice_session' || name == 'stop_practice_session') {
        // Logic handled via onHardwareCommand
      } else {
        responsePayload = {"result": "error", "message": "Unknown function"};
      }

      responseParts.add({
        "function_response": {
          "name": name,
          if (id != null) "call_id": id,
          "response": responsePayload
        }
      });
    }

    // [PROTOCOL-SANITY] Purge any null or empty objects before buffering
    final cleanParts = responseParts.where((part) => part.isNotEmpty).toList();
    if (cleanParts.isEmpty) return;

    _pendingToolResponses.addAll(cleanParts);
    debugPrint("MUSE_LOG: [EUTE] Tool responses buffered (${_pendingToolResponses.length} total). Waiting for server_turn_complete.");
  }

  void _dispatchPendingToolResponses() {
    if (_isDisposed || _pendingToolResponses.isEmpty) return;

    if (_channel != null && !_isDisposed) {
      try {
        // [DOUBLE-ANCHOR-HARDENING] 
        // 1. Dispatch tool results first (turn_complete: false)
        final resultsPayload = {
          "client_content": {
            "turns": [
              {
                "role": "user",
                "parts": List<Map<String, dynamic>>.from(_pendingToolResponses)
              }
            ],
            "turn_complete": false
          }
        };
        _channel!.sink.add(jsonEncode(resultsPayload));
        
        // 2. Dispatch turn closure after staggered delay (30ms)
        // This prevents the "empty turn" race condition in Gemini's Bidi protocol
        Future.delayed(const Duration(milliseconds: 30), () {
          if (_channel != null && !_isDisposed) {
            final closurePayload = {
              "client_content": {
                "turn_complete": true
              }
            };
            _channel!.sink.add(jsonEncode(closurePayload));
            debugPrint("MUSE_LOG: [EUTE] Protocol Anchor Hardened: Staggered closure dispatched.");
            LabLogService().log("PROTOCOL", "TURN_CLOSE", metadata: "Batched closure with staggered delay");
          }
        });

        _pendingToolResponses.clear();
      } catch (e) {
        debugPrint("MUSE_LOG: [EUTE] Sink Add Error (Buffered Response): $e");
      }
    }
  }

  double _calculateRMS(Uint8List pcm) {
    if (pcm.isEmpty) return 0.0;
    try {
      final samples = pcm.buffer.asInt16List(pcm.offsetInBytes, pcm.length ~/ 2);
      double sum = 0.0;
      for (final sample in samples) {
        final normalized = sample / 32768.0;
        sum += normalized * normalized;
      }
      return math.sqrt(sum / samples.length);
    } catch (e) {
      return 0.0;
    }
  }
}
