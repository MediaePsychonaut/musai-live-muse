import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

/// message types for communicating with the PitchDetector Isolate
class PitchDetectorParams {
  final Uint8List frame;
  final int sampleRate;

  PitchDetectorParams(this.frame, this.sampleRate);
}

class PitchDetectorResult {
  final double pitch;
  final double volume;

  PitchDetectorResult(this.pitch, this.volume);
}

class PitchDetector {
  Isolate? _isolate;
  SendPort? _sendPort;
  final _resultController = StreamController<PitchDetectorResult>.broadcast();

  Stream<PitchDetectorResult> get results => _resultController.stream;

  Future<void> init() async {
    final receivePort = ReceivePort();
    _isolate = await Isolate.spawn(_isolateEntry, receivePort.sendPort);

    receivePort.listen((message) {
      if (message is SendPort) {
        _sendPort = message;
      } else if (message is PitchDetectorResult) {
        _resultController.add(message);
      }
    });
  }

  void processFrame(Uint8List frame, int sampleRate) {
    _sendPort?.send(PitchDetectorParams(frame, sampleRate));
  }

  void dispose() {
    _isolate?.kill();
    _resultController.close();
  }

  static void _isolateEntry(SendPort sendPort) {
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    receivePort.listen((message) {
      if (message is PitchDetectorParams) {
        final result = _analyze(message.frame, message.sampleRate);
        sendPort.send(result);
      }
    });
  }

  static PitchDetectorResult _analyze(Uint8List frame, int sampleRate) {
    if (frame.isEmpty) return PitchDetectorResult(0.0, 0.0);

    // Convert to float samples
    final samples = Float32List(frame.length ~/ 2);
    double sumSq = 0;
    for (int i = 0; i < samples.length; i++) {
      int sample = frame[i * 2] | (frame[i * 2 + 1] << 8);
      if (sample > 32767) sample -= 65536;
      final floatSample = sample / 32768.0;
      samples[i] = floatSample;
      sumSq += floatSample * floatSample;
    }

    final volume = math.sqrt(sumSq / samples.length);
    if (volume < 0.01) return PitchDetectorResult(0.0, volume);

    // Simple Autocorrelation
    double maxCorr = -1.0;
    int bestLag = -1;

    // Search range for pitch (e.g., 80Hz to 1000Hz)
    final minLag = sampleRate ~/ 1000;
    final maxLag = sampleRate ~/ 80;

    for (int lag = minLag; lag < maxLag; lag++) {
      double corr = 0;
      int count = 0;
      for (int i = 0; i < samples.length - lag; i++) {
        corr += samples[i] * samples[i + lag];
        count++;
      }
      if (count > 0) {
        corr /= count;
        if (corr > maxCorr) {
          maxCorr = corr;
          bestLag = lag;
        }
      }
    }

    double pitch = 0.0;
    if (bestLag > 0 && maxCorr > 0.1) {
      pitch = sampleRate / bestLag;
    }

    return PitchDetectorResult(pitch, volume);
  }
}
