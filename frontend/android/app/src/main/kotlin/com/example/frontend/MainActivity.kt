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
    
    private var telemetryChannel: BasicMessageChannel<Any>? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    companion object {
        init {
            System.loadLibrary("oboe_pulse_engine")
        }
    }

    external fun startPulseEngine(bpm: Double)
    external fun stopPulseEngine()
    
    external fun startDroneEngine(freq: Double)
    external fun stopDroneEngine()

    external fun updateBpm(bpm: Double)
    external fun updateDroneFreq(freq: Double)

    external fun writeVocalData(data: ByteArray): Double
    external fun clearVocalBuffer()
    external fun updateSignature(signature: Int)
    external fun stopVocalStream()

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
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
                    result.success(null)
                }
                "write" -> {
                    val data = call.argument<ByteArray>("data")
                    if (data != null) {
                        val rms = writeVocalData(data)
                        telemetryChannel?.send(rms)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Data is null", null)
                    }
                }
                "clearVocal" -> {
                    clearVocalBuffer()
                    result.success(null)
                }
                "stopVocal" -> {
                    stopVocalStream()
                    result.success(null)
                }
                "dispose" -> {
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.frontend/pulse_engine").setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val bpm = call.argument<Double>("bpm") ?: 60.0
                    startPulseEngine(bpm)
                    result.success(null)
                }
                "updateBpm" -> {
                    val bpm = call.argument<Double>("bpm") ?: 60.0
                    updateBpm(bpm)
                    result.success(null)
                }
                "updateSignature" -> {
                    val signature = call.argument<Int>("signature") ?: 4
                    updateSignature(signature)
                    result.success(null)
                }
                "stop" -> {
                    stopPulseEngine()
                    result.success(null)
                }
                "startDrone" -> {
                    val freq = call.argument<Double>("freq") ?: 440.0
                    startDroneEngine(freq)
                    result.success(null)
                }
                "updateDroneFreq" -> {
                    val freq = call.argument<Double>("freq") ?: 440.0
                    updateDroneFreq(freq)
                    result.success(null)
                }
                "stopDrone" -> {
                    stopDroneEngine()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onDestroy() {
        stopPulseEngine()
        stopDroneEngine()
        super.onDestroy()
    }

    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        if (level >= android.content.ComponentCallbacks2.TRIM_MEMORY_RUNNING_CRITICAL) {
            stopPulseEngine()
            stopDroneEngine()
        }
    }
}
