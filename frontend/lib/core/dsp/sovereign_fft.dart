import 'dart:math' as math;
import 'dart:typed_data';

/// SOVEREIGN FFT (V2.0)
/// High-performance Real FFT Engine in pure Dart.
/// Implements Smith Ch.12 Real-to-Complex optimization.
class SovereignFFT {
  final int n;
  late final int _n2; // n/2
  late final Float64List _hannWindow;
  late final Float64List _sinTable;
  late final Float64List _cosTable;
  late final Int32List _bitReversalTable;

  // Work buffers (pre-allocated for zero-allocation hot loop)
  late final Float64List _real;
  late final Float64List _imag;
  late final Float64List _resultBuffer;

  late final Float64List _unpackSinTable;
  late final Float64List _unpackCosTable;

  SovereignFFT(this.n) {
    if ((n & (n - 1)) != 0) {
      throw ArgumentError('FFT size must be a power of 2');
    }
    _n2 = n >> 1;

    _hannWindow = Float64List(n);
    for (int i = 0; i < n; i++) {
      _hannWindow[i] = 0.5 * (1 - math.cos(2 * math.pi * i / (n - 1)));
    }

    // Twiddle factors for Complex FFT of size N/2
    final complexSteps = (math.log(_n2) / math.log(2)).round();
    _sinTable = Float64List(_n2);
    _cosTable = Float64List(_n2);
    for (int i = 0; i < _n2; i++) {
        _sinTable[i] = math.sin(-2 * math.pi * i / _n2);
        _cosTable[i] = math.cos(-2 * math.pi * i / _n2);
    }

    // [V2.1] Unpacking tables for Smith Ch.12
    final unpackSize = (_n2 >> 1) + 1;
    _unpackSinTable = Float64List(unpackSize);
    _unpackCosTable = Float64List(unpackSize);
    for (int k = 0; k < unpackSize; k++) {
      final phase = -2 * math.pi * k / n;
      _unpackSinTable[k] = math.sin(phase);
      _unpackCosTable[k] = math.cos(phase);
    }

    _bitReversalTable = Int32List(_n2);
    for (int i = 0; i < _n2; i++) {
      int reversed = 0;
      int tempI = i;
      for (int j = 0; j < complexSteps; j++) {
        reversed = (reversed << 1) | (tempI & 1);
        tempI >>= 1;
      }
      _bitReversalTable[i] = reversed;
    }

    _real = Float64List(_n2);
    _imag = Float64List(_n2);
    _resultBuffer = Float64List(_n2 + 1);
  }

  /// Processes a real audio frame of size N.
  /// Returns a pre-allocated Float64List view of the spectrum magnitude (Bins 0 to N/2).
  Float64List processFrame(Float32List frame) {
    if (frame.length != n) {
      throw ArgumentError('Frame length must match FFT size $n');
    }

    // 1. PACKING (Smith Ch.12)
    // Map N real samples to N/2 complex samples
    for (int i = 0; i < _n2; i++) {
      // Apply Hann Window during packing
      // Use local variable to avoid repeated indexing/lookup
      final i2 = i << 1;
      _real[i] = frame[i2] * _hannWindow[i2];
      _imag[i] = frame[i2 + 1] * _hannWindow[i2 + 1];
    }

    // 2. FFT-N/2 (Complex FFT of size N/2)
    _complexFFT(_real, _imag);

    // 3. UNPACKING & MAGNITUDE
    // Extract real and imaginary components of original Real FFT
    
    // DC and Nyquist components
    final f0r = _real[0];
    final f0i = _imag[0];
    
    // Smith Ch 12: The first and last bins of the N/2 FFT contain information for DC and Nyquist
    _resultBuffer[0] = (f0r + f0i).abs(); // DC
    _resultBuffer[_n2] = (f0r - f0i).abs(); // Nyquist

    for (int k = 1; k < (_n2 >> 1) + 1; k++) {
      final kn = _n2 - k;
      
      final rk = _real[k];
      final ik = _imag[k];
      final rkn = _real[kn];
      final ikn = _imag[kn];

      final ar = 0.5 * (rk + rkn);
      final ai = 0.5 * (ik - ikn);
      final br = 0.5 * (ik + ikn);
      final bi = 0.5 * (rkn - rk);

      // [V2.1] O(1) Table Lookup
      final c = _unpackCosTable[k];
      final s = _unpackSinTable[k];

      final realK = ar + c * br - s * bi;
      final imagK = ai + c * bi + s * br;
      
      _resultBuffer[k] = math.sqrt(realK * realK + imagK * imagK);
      
      // Symmetry for the upper half (not strictly needed if only returning _n2+1)
      if (kn != k) {
        final realNK = ar - (c * br - s * bi);
        final imagNK = -ai + (c * bi + s * br);
        _resultBuffer[kn] = math.sqrt(realNK * realNK + imagNK * imagNK);
      }
    }

    return _resultBuffer;
  }

  /// Extracts Violin Resonance (Bins 12-42) per Müller-Hz Telemetry.
  double getViolinResonance(Float64List magnitudeSpectrum) {
    double sumSq = 0;
    const startBin = 12;
    const endBin = 42;
    const m = endBin - startBin + 1;

    for (int k = startBin; k <= endBin; k++) {
      final mag = magnitudeSpectrum[k];
      sumSq += mag * mag;
    }

    return math.sqrt(sumSq / m);
  }

  void _complexFFT(Float64List real, Float64List imag) {
    // Bit-reversal permutation
    for (int i = 0; i < _n2; i++) {
        final j = _bitReversalTable[i];
        if (i < j) {
            final tempR = real[i];
            real[i] = real[j];
            real[j] = tempR;

            final tempI = imag[i];
            imag[i] = imag[j];
            imag[j] = tempI;
        }
    }

    // Cooley-Tukey Butterfly Engine
    int step = 1;
    while (step < _n2) {
      final jump = step << 1;
      final twiddleStep = _n2 ~/ jump;

      for (int i = 0; i < step; i++) {
        final twiddleR = _cosTable[i * twiddleStep];
        final twiddleI = _sinTable[i * twiddleStep];

        for (int j = i; j < _n2; j += jump) {
          final k = j + step;
          final r = real[k];
          final im = imag[k];

          final tr = r * twiddleR - im * twiddleI;
          final ti = r * twiddleI + im * twiddleR;

          real[k] = real[j] - tr;
          imag[k] = imag[j] - ti;
          real[j] += tr;
          imag[j] += ti;
        }
      }
      step = jump;
    }
  }
}
