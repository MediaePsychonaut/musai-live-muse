import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'sovereign_fft.dart';

/// message types for communicating with the PitchDetector Isolate
class PitchDetectorParams {
  final Uint8List frame;
  final int sampleRate;

  PitchDetectorParams(this.frame, this.sampleRate);
}

class PitchDetectorResult {
  final double pitch;
  final double centsDeviation; // Added: Deviation from A440
  final double volume;
  final List<double> spectrum;
  final double violinResonance;

  PitchDetectorResult(this.pitch, this.centsDeviation, this.volume, this.spectrum, this.violinResonance);
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

    // [SOVEREIGN-FFT] Zero-allocation engine (size 1024)
    final fft = SovereignFFT(1024);
    
    // [V2.1] Pre-allocated pre-processor buffer
    final samplesBuffer = Float32List(1024);

    receivePort.listen((message) {
      if (message is PitchDetectorParams) {
        final result = _analyze(fft, samplesBuffer, message.frame, message.sampleRate);
        sendPort.send(result);
      }
    });
  }

  static PitchDetectorResult _analyze(SovereignFFT fft, Float32List samples, Uint8List frame, int sampleRate) {
    if (frame.isEmpty) return PitchDetectorResult(0.0, 0.0, 0.0, const [], 0.0);

    // Convert to float samples into the pre-allocated buffer
    final numSamples = math.min(samples.length, frame.length ~/ 2);
    double sumSq = 0;
    for (int i = 0; i < numSamples; i++) {
      int sample = frame[i * 2] | (frame[i * 2 + 1] << 8);
      if (sample > 32767) sample -= 65536;
      final floatSample = sample / 32768.0;
      samples[i] = floatSample;
      sumSq += floatSample * floatSample;
    }
    
    // Zero out the rest of the buffer if frame is smaller (prevents ghosting)
    if (numSamples < samples.length) {
      samples.fillRange(numSamples, samples.length, 0.0);
    }

    final volume = math.sqrt(sumSq / numSamples);
    if (volume < 0.01) return PitchDetectorResult(0.0, 0.0, volume, const [], 0.0);

    // [SPECTRAL-EAR] Noise Suppression Scaffold
    _applyNoiseSuppression(samples);

    //Simple Autocorrelation
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

    // [SOVEREIGN-FFT] SPECTRAL ANALYSIS
    // Process frame directly from Float32List to avoid copying
    final magnitudeSpectrum = fft.processFrame(samples);
    
    // [SOVEREIGN-FFT] RESONANCE EXTRACTION
    final resonance = fft.getViolinResonance(magnitudeSpectrum);
    
    // [PITCH DEVIATION CALCULATION]
    // A4 = 440Hz. Formula: cents = 1200 * log2(pitch / 440)
    double centsDeviation = 0.0;
    if (pitch > 0) {
      centsDeviation = 1200 * (math.log(pitch / 440.0) / math.ln2);
    }

    // DIRECT DELIVERY: Float64List implements List<double>. 
    // Sending over the port will perform the necessary copy for the UI isolate.
    return PitchDetectorResult(pitch, centsDeviation, volume, magnitudeSpectrum, resonance);
  }

  /// [SPECTRAL-EAR] Frequency Purification
  /// 
  /// Placeholder for FFT-based noise subtraction.
  /// Enforces librosa-style spectral subtraction logic.
  static void _applyNoiseSuppression(Float32List samples) {
    // 1. FFT Transformation (Future: Use fftea or custom radix-2)
    // 2. Estimate Noise Floor (Median of magnitudes)
    // 3. Spectral Subtraction (Magnitude = max(Magnitude - Alpha * Noise, 0))
    // 4. Inverse FFT
    
    // CURRENT: Pass-through until FFT engine is integrated.
    // debugPrint("MUSE_LOG: [EUTE] Applying spectral subtraction...");
  }
}
