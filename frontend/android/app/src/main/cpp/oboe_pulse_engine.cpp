#include <jni.h>
#include <oboe/Oboe.h>
#include <math.h>
#include <android/log.h>

#define LOG_TAG "OboePulseEngine"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

using namespace oboe;

class PulseEngine : public AudioStreamCallback {
private:
    std::shared_ptr<AudioStream> stream;
    double mPhase = 0.0;
    double mPhaseIncrement = 0.0;
    double mOscillatorPhase = 0.0;
    double mBpm = 60.0;
    bool mIsPlaying = false;
    int mSampleRate = 48000;

    // Drone
    double mDroneFreq = 0.0;
    double mDronePhase = 0.0;
    double mDronePhaseIncrement = 0.0;
    bool mDronePlaying = false;

    void updatePhaseIncrement() {
        // We want a pulse every 60/BPM seconds.
        // So frequency of the pulse is BPM/60 Hz.
        double pulseFrequency = mBpm / 60.0;
        mPhaseIncrement = pulseFrequency / (double)mSampleRate;
    }

public:
    PulseEngine() {}

    bool start(double bpm) {
        mBpm = bpm;
        mPhase = 0.0;
        mOscillatorPhase = 0.0;
        mIsPlaying = true;

        AudioStreamBuilder builder;
        builder.setFormat(AudioFormat::Float)
            ->setChannelCount(1)
            ->setPerformanceMode(PerformanceMode::LowLatency)
            ->setSharingMode(SharingMode::Exclusive)
            ->setCallback(this);

        Result result = builder.openStream(stream);
        if (result != Result::OK) {
            LOGE("Failed to open stream. Error: %s", convertToText(result));
            return false;
        }

        mSampleRate = stream->getSampleRate();
        updatePhaseIncrement();

        result = stream->requestStart();
        if (result != Result::OK) {
            LOGE("Failed to start stream. Error: %s", convertToText(result));
            return false;
        }

        LOGI("Pulse Engine Started: BPM %f", mBpm);
        return true;
    }

    void stop() {
        if (stream) {
            stream->requestStop();
            stream->close();
            stream.reset();
        }
        mIsPlaying = false;
        mDronePlaying = false;
        LOGI("Pulse Engine Stopped.");
    }

    void startDrone(double freq) {
        mDroneFreq = freq;
        mDronePhase = 0.0;
        mDronePhaseIncrement = mDroneFreq / (double)mSampleRate;
        mDronePlaying = true;
        
        // Ensure stream is running if only drone is started
        if (!mIsPlaying && !stream) {
            // We start a "silent" metronome basically, or just open a stream
            start(mBpm);
            mIsPlaying = false; // We aren't playing the metronome
        }
    }

    void stopDrone() {
        mDronePlaying = false;
        // If metronome isn't playing either, we could stop stream, but let's keep it simple for now
    }

    DataCallbackResult onAudioReady(AudioStream *oboeStream, void *audioData, int32_t numFrames) override {
        float *floatData = (float *) audioData;

        for (int i = 0; i < numFrames; ++i) {
            float sampleValue = 0.0f;

            if (mIsPlaying) {
                mPhase += mPhaseIncrement;
                
                // Render a short 440Hz tick when the macro phase resets
                if (mPhase >= 1.0) {
                    mPhase -= 1.0;
                    mOscillatorPhase = 1.0; // Trigger tick envelope
                }

                if (mOscillatorPhase > 0.0) {
                    // Generate a 440Hz sine wave enveloped by an exponential decay
                    mOscillatorPhase -= 0.005; // Decay rate
                    if (mOscillatorPhase < 0.0) mOscillatorPhase = 0.0;

                    // Simple sine oscillator for the tick
                    sampleValue += sin(mOscillatorPhase * M_PI * 440.0 * 2.0) * mOscillatorPhase * 0.5f;
                }
            }

            if (mDronePlaying) {
                mDronePhase += mDronePhaseIncrement;
                if (mDronePhase >= 1.0) {
                    mDronePhase -= 1.0;
                }
                
                // Pure sine drone at lower volume
                sampleValue += sin(mDronePhase * M_PI * 2.0) * 0.2f; 
            }

            // Simple clipping protection
            if (sampleValue > 1.0f) sampleValue = 1.0f;
            if (sampleValue < -1.0f) sampleValue = -1.0f;

            floatData[i] = sampleValue;
        }

        return DataCallbackResult::Continue;
    }
};

static PulseEngine engine;

extern "C" JNIEXPORT void JNICALL
Java_com_example_frontend_MainActivity_startPulseEngine(JNIEnv* env, jobject /* this */, jdouble bpm) {
    engine.start(bpm);
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_frontend_MainActivity_stopPulseEngine(JNIEnv* env, jobject /* this */) {
    engine.stop();
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_frontend_MainActivity_startDroneEngine(JNIEnv* env, jobject /* this */, jdouble freq) {
    engine.startDrone(freq);
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_frontend_MainActivity_stopDroneEngine(JNIEnv* env, jobject /* this */) {
    engine.stopDrone();
}
