import 'dart:typed_data';
import 'dart:collection';

/// [JITTER-BUFFER] Sequence Stabilization Engine
/// 
/// Designed to sequester 24kHz PCM chunks and release them sequentially
/// to the Audio Sink to prevent network-induced playback stutter.
class JitterBuffer {
  final Queue<Uint8List> _buffer = Queue<Uint8List>();
  final int maxBufferSize;

  JitterBuffer({this.maxBufferSize = 10});

  /// Add a decoded PCM chunk to the buffer
  void addChunk(Uint8List chunk) {
    if (_buffer.length >= maxBufferSize) {
      // Buffer overflow: Drop oldest chunk to maintain real-time relevance
      _buffer.removeFirst();
    }
    _buffer.addLast(chunk);
  }

  /// Check if the buffer has enough data to start playback
  bool get hasSufficientData => _buffer.length >= 3;

  /// Retrieve the next chunk for the Audio Sink
  Uint8List? nextChunk() {
    if (_buffer.isEmpty) return null;
    return _buffer.removeFirst();
  }

  /// Purge all data
  void clear() {
    _buffer.clear();
  }

  bool get isEmpty => _buffer.isEmpty;
  int get length => _buffer.length;
}
