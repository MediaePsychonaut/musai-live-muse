package com.example.frontend

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BasicMessageChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import java.util.concurrent.Executors
import kotlin.math.sqrt

class MainActivity : FlutterActivity() {
    private val CHANNEL = "musai.live/audio_sink"
    private val TELEMETRY_CHANNEL = "musai.live/audio_telemetry"
    
    private var audioTrack: AudioTrack? = null
    private val executor = Executors.newSingleThreadExecutor()
    private var telemetryChannel: BasicMessageChannel<Any>? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // [MISSION 1] Early initialization of Audio SINK
        initAudioTrack(24000)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        telemetryChannel = BasicMessageChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            TELEMETRY_CHANNEL,
            StandardMessageCodec.INSTANCE
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "init" -> {
                    // Re-init if sample rate changes, otherwise we use onCreate default
                    val sampleRate = call.argument<Int>("sampleRate") ?: 24000
                    initAudioTrack(sampleRate)
                    result.success(null)
                }
                "write" -> {
                    val data = call.argument<ByteArray>("data")
                    if (data != null) {
                        writeAudio(data)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Data is null", null)
                    }
                }
                "dispose" -> {
                    disposeAudioTrack()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun initAudioTrack(sampleRate: Int) {
        disposeAudioTrack()
        
        val minBufferSize = AudioTrack.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )

        audioTrack = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(sampleRate)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build()
            )
            .setBufferSizeInBytes(minBufferSize * 8)
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()
            
        audioTrack?.play()
    }

    private fun writeAudio(data: ByteArray) {
        executor.execute {
            audioTrack?.write(data, 0, data.size)
            calculateAndSendTelemetry(data)
        }
    }

    private fun calculateAndSendTelemetry(data: ByteArray) {
        // RMS Calculation for PCM 16-bit
        var sumSq = 0.0
        val sampleCount = data.size / 2
        if (sampleCount == 0) return

        for (i in 0 until sampleCount) {
            // Read 16-bit sample (Little Endian)
            val b1 = data[i * 2].toInt() and 0xFF
            val b2 = data[i * 2 + 1].toInt() and 0xFF
            var sample = (b1 or (b2 shl 8)).toShort().toDouble()
            
            val normalized = sample / 32768.0
            sumSq += normalized * normalized
        }

        val rms = sqrt(sumSq / sampleCount)
        
        // Return to main thread to send via BasicMessageChannel
        mainHandler.post {
            telemetryChannel?.send(rms)
        }
    }

    private fun disposeAudioTrack() {
        audioTrack?.stop()
        audioTrack?.release()
        audioTrack = null
    }

    override fun onDestroy() {
        super.onDestroy()
        disposeAudioTrack()
        executor.shutdown()
    }
}
