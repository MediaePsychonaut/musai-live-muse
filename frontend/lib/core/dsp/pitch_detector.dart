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
  final String noteName;
  final double volume;
  final Float64List spectrum;
  final double resonance;

  PitchDetectorResult(this.pitch, this.centsDeviation, this.noteName, this.volume, this.spectrum, this.resonance);
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

    // [SOVEREIGN-FFT] Zero-allocation engine (size 2048)
    final fft = SovereignFFT(2048);
    
    // [V2.1] Pre-allocated pre-processor buffer
    final samplesBuffer = Float32List(2048);

    receivePort.listen((message) {
      if (message is PitchDetectorParams) {
        final result = _analyze(fft, samplesBuffer, message.frame, message.sampleRate);
        sendPort.send(result);
      }
    });
  }

  static PitchDetectorResult _analyze(SovereignFFT fft, Float32List samples, Uint8List frame, int sampleRate) {
    if (frame.isEmpty) return PitchDetectorResult(0.0, 0.0, "--", 0.0, Float64List(0), 0.0);

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
    // [SENSORY-RECLAMATION] Surgical Threshold for Tuner Sensitivity
    if (volume < 0.002) {
      return PitchDetectorResult(0.0, 0.0, "--", volume, Float64List(fft.n ~/ 2), 0.0);
    }

    // [SPECTRAL-EAR] Noise Suppression Scaffold
    _applyNoiseSuppression(samples);

    // [SENSORY-STABILIZATION] Normalized Autocorrelation
    // Ensures threshold (0.4) is independent of signal volume (0.002 floor)
    double maxCorr = -1.0;
    int bestLag = -1;

    // Search range for pitch (e.g., 40Hz to 1000Hz)
    final minLag = sampleRate ~/ 1000;
    final maxLag = sampleRate ~/ 40;

    // Pre-calculate signal energy for normalization
    double energy = sumSq / numSamples;
    if (energy < 1e-10) energy = 1.0; // Prevent div by zero

    for (int lag = minLag; lag < maxLag; lag++) {
      double corr = 0;
      int count = 0;
      for (int i = 0; i < samples.length - lag; i++) {
        corr += samples[i] * samples[i + lag];
        count++;
      }
      if (count > 0) {
        // Normalize by energy to make threshold volume-independent
        double normalizedCorr = (corr / count) / energy;
        if (normalizedCorr > maxCorr) {
          maxCorr = normalizedCorr;
          bestLag = lag;
        }
      }
    }

    double pitch = 0.0;
    // [THRESHOLD-ALIGNMENT] 0.5 correlation is the typical cutoff for periodicity
    if (bestLag > 0 && maxCorr > 0.45) {
      // [PITCH-SOVEREIGNTY] Parabolic Interpolation for sub-bin precision
      double leftCorr = 0;
      double rightCorr = 0;
      
      if (bestLag > minLag && bestLag < maxLag - 1) {
        _calculateLagCorr(samples, bestLag - 1, (c) => leftCorr = c / energy);
        _calculateLagCorr(samples, bestLag + 1, (c) => rightCorr = c / energy);
        
        double denominator = 2 * (leftCorr - 2 * maxCorr + rightCorr);
        double delta = (denominator != 0) ? (leftCorr - rightCorr) / denominator : 0.0;
        pitch = sampleRate / (bestLag + delta);
      } else {
        pitch = sampleRate / bestLag;
      }
    }

    // [SOVEREIGN-FFT] SPECTRAL ANALYSIS
    final magnitudeSpectrum = fft.processFrame(samples);
    
    // [SOVEREIGN-FFT] RESONANCE EXTRACTION
    final resonance = fft.getViolinResonance(magnitudeSpectrum);
    
    // [NOTE-INTELLIGENCE] Find nearest note and relative deviation
    double centsDeviation = 0.0;
    String noteName = "--";
    if (pitch > 0) {
      // MIDI formula: n = 12 * log2(f/440) + 69
      double midiValue = 12 * (math.log(pitch / 440.0) / math.ln2) + 69.0;
      int nearestMidi = midiValue.round();
      centsDeviation = (midiValue - nearestMidi) * 100.0;
      
      const notes = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];
      int octave = (nearestMidi ~/ 12) - 1;
      int noteIndex = nearestMidi % 12;
      noteName = "${notes[noteIndex]}$octave";
    }

    return PitchDetectorResult(pitch, centsDeviation, noteName, volume, magnitudeSpectrum, resonance);
  }

  static void _calculateLagCorr(Float32List samples, int lag, Function(double) onResult) {
    double corr = 0;
    int count = 0;
    for (int i = 0; i < samples.length - lag; i++) {
      corr += samples[i] * samples[i + lag];
      count++;
    }
    onResult(count > 0 ? corr / count : 0.0);
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
