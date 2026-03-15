#include <jni.h>
#include <oboe/Oboe.h>
#include <math.h>
#include <android/log.h>
#include <vector>
#include <atomic>

#define LOG_TAG "OboePulseEngine"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

using namespace oboe;

class RingBuffer {
public:
    RingBuffer(size_t capacity) : buffer(capacity), head(0), tail(0), size(0) {}

    size_t write(const int16_t* data, size_t numSamples) {
        size_t written = 0;
        for (size_t i = 0; i < numSamples; ++i) {
            if (size.load() < buffer.size()) {
                buffer[head] = data[i];
                head = (head + 1) % buffer.size();
                size.fetch_add(1);
                written++;
            } else {
                break; // Buffer full
            }
        }
        return written;
    }

    bool read(int16_t& sample) {
        if (size.load() > 0) {
            sample = buffer[tail];
            tail = (tail + 1) % buffer.size();
            size.fetch_sub(1);
            return true;
        }
        return false;
    }

    size_t available() const {
        return size.load();
    }

private:
    std::vector<int16_t> buffer;
    size_t head;
    size_t tail;
    std::atomic<size_t> size;
};

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

    // Vocal Ring Buffer (4 seconds @ 24kHz = 96000 samples)
    RingBuffer mVocalBuffer{96000};

    void updatePhaseIncrement() {
        // We want a pulse every 60/BPM seconds.
        // So frequency of the pulse is BPM/60 Hz.
        double pulseFrequency = mBpm / 60.0;
        mPhaseIncrement = pulseFrequency / (double)mSampleRate;
    }

public:
    void updateBpm(double bpm) {
        mBpm = bpm;
        updatePhaseIncrement();
        LOGI("Pulse Engine BPM Updated: %f", mBpm);
    }

    void updateDroneFreq(double freq) {
        mDroneFreq = freq;
        if (stream) {
            mDronePhaseIncrement = mDroneFreq / (double)stream->getSampleRate();
        }
        LOGI("Drone Engine FREQ Updated: %f", mDroneFreq);
    }

    PulseEngine() {}

    bool start(double bpm) {
        mBpm = bpm;
        mPhase = 0.0;
        mOscillatorPhase = 0.0;
        mIsPlaying = true;

        AudioStreamBuilder builder;
        builder.setFormat(AudioFormat::Float)
            ->setChannelCount(1)
            ->setSampleRate(24000) // MATCH GEMINI
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

        LOGI("Pulse Engine Started: BPM %f at %d Hz", mBpm, mSampleRate);
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
        
        // Ensure stream is running
        if (!stream) {
            start(mBpm); // Opens stream
            mIsPlaying = false; // Turn off tick
        } else {
             mSampleRate = stream->getSampleRate();
        }
        
        mDronePhaseIncrement = mDroneFreq / (double)mSampleRate;
        mDronePlaying = true;
        LOGI("Drone Engine Started: FREQ %f", mDroneFreq);
    }

    void stopDrone() {
        mDronePlaying = false;
        LOGI("Drone Engine Stopped.");
        if (!mIsPlaying && stream) {
            stop(); // If nothing is playing, close stream
        }
    }

    double writeVocalData(const int16_t* data, int32_t numSamples) {
        if (numSamples <= 0) return 0.0;
        // Calculate RMS in C++ for performance
        double sumSq = 0.0;
        for (int i = 0; i < numSamples; ++i) {
            double sample = data[i] / 32768.0;
            sumSq += sample * sample;
        }
        double rms = sqrt(sumSq / numSamples);

        mVocalBuffer.write(data, numSamples);
        return rms;
    }

    void updateBpm(double bpm) {
        mBpm = bpm;
        updatePhaseIncrement();
        LOGI("BPM Updated: %f", mBpm);
    }

    void updateDroneFreq(double freq) {
        mDroneFreq = freq;
        if (stream) {
            mSampleRate = stream->getSampleRate();
            mDronePhaseIncrement = mDroneFreq / (double)mSampleRate;
        }
        LOGI("Drone Freq Updated: %f", mDroneFreq);
    }

    DataCallbackResult onAudioReady(AudioStream *oboeStream, void *audioData, int32_t numFrames) override {
        float *floatData = (float *) audioData;
        if (!floatData) return DataCallbackResult::Stop;

        for (int i = 0; i < numFrames; ++i) {
            float sampleValue = 0.0f;

            if (mIsPlaying) {
                mPhase += mPhaseIncrement;
                
                // Render a tick
                if (mPhase >= 1.0) {
                    mPhase -= 1.0;
                    mOscillatorPhase = 1.0; // Trigger tick envelope
                }

                if (mOscillatorPhase > 0.0) {
                    // C5 (523.25 Hz) for a clearer, more pleasant tick
                    mOscillatorPhase -= 0.01; // Faster decay for punch
                    if (mOscillatorPhase < 0.0) mOscillatorPhase = 0.0;

                    sampleValue += sin(mOscillatorPhase * M_PI * 523.25 * 2.0) * mOscillatorPhase * 0.8f;
                }
            }

            if (mDronePlaying) {
                mDronePhase += mDronePhaseIncrement;
                if (mDronePhase >= 1.0) {
                    mDronePhase -= 1.0;
                }
                
                // Pure sine drone - INCREASE GAIN to 0.4
                sampleValue += sin(mDronePhase * M_PI * 2.0) * 0.4f; 
            }

            // Mix AI Vocal from Ring Buffer
            int16_t vocalSampleRaw;
            if (mVocalBuffer.read(vocalSampleRaw)) {
                float vocalSample = (float)vocalSampleRaw / 32768.0f;
                sampleValue += vocalSample * 1.0f; // Full volume priority
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
Java_com_example_frontend_MainActivity_updatePulseEngineBpm(JNIEnv* env, jobject /* this */, jdouble bpm) {
    engine.updateBpm(bpm);
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
Java_com_example_frontend_MainActivity_updateDroneEngineFreq(JNIEnv* env, jobject /* this */, jdouble freq) {
    engine.updateDroneFreq(freq);
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_frontend_MainActivity_stopDroneEngine(JNIEnv* env, jobject /* this */) {
    engine.stopDrone();
}

extern "C" JNIEXPORT jdouble JNICALL
Java_com_example_frontend_MainActivity_writeVocalData(JNIEnv* env, jobject /* this */, jbyteArray data) {
    jsize len = env->GetArrayLength(data);
    jbyte* bufferPtr = env->GetByteArrayElements(data, NULL);
    
    // Bytes to samples (PCM16)
    int32_t numSamples = len / 2;
    double rms = engine.writeVocalData((const int16_t*)bufferPtr, numSamples);
    
    env->ReleaseByteArrayElements(data, bufferPtr, JNI_ABORT);
    return rms;
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_frontend_MainActivity_updateBpm(JNIEnv* env, jobject /* this */, jdouble bpm) {
    engine.updateBpm(bpm);
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_frontend_MainActivity_updateDroneFreq(JNIEnv* env, jobject /* this */, jdouble freq) {
    engine.updateDroneFreq(freq);
}
