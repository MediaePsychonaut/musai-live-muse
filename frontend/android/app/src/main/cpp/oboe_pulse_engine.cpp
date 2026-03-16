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

    void clear() {
        head = 0;
        tail = 0;
        size.store(0);
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
    std::recursive_mutex mLock;
    double mPhase = 0.0;
    double mPhaseIncrement = 0.0;
    double mOscillatorPhase = 0.0;
    double mBpm = 60.0;
    std::atomic<bool> mIsPlaying{false};
    int mSampleRate = 48000;

    // Drone
    double mDroneFreq = 0.0;
    double mDronePhase = 0.0;
    double mDronePhaseIncrement = 0.0;
    std::atomic<bool> mDronePlaying{false};
    
    // Anti-Click Gain Ramping
    std::atomic<float> mDroneGain{0.0f};
    std::atomic<float> mTargetDroneGain{0.0f};
    const float kGainStep = 0.001f; // ~50ms ramp at 24kHz

    // Metronome Time Signature
    std::atomic<int> mSignature{4};
    std::atomic<int> mTickCount{0};

    // Vocal Ring Buffer (8 seconds @ 24kHz = 192000 samples)
    RingBuffer mVocalBuffer{192000};
    std::atomic<bool> mClearVocalBuffer{false};

    void updatePhaseIncrement() {
        // We want a pulse every 60/BPM seconds.
        // So frequency of the pulse is BPM/60 Hz.
        double pulseFrequency = mBpm / 60.0;
        mPhaseIncrement = pulseFrequency / (double)mSampleRate;
    }

public:
    PulseEngine() {}

    bool start(double bpm) {
        std::lock_guard<std::recursive_mutex> lock(mLock);
        mBpm = bpm;
        mPhase = 0.0;
        mOscillatorPhase = 0.0;
        mIsPlaying = true;
        mTickCount = 0;
        mVocalBuffer.clear();
        mClearVocalBuffer = false;

        if (stream) {
            updatePhaseIncrement();
            LOGI("Pulse Engine Resumed: BPM %f", mBpm);
            return true;
        }

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
        std::lock_guard<std::recursive_mutex> lock(mLock);
        mIsPlaying = false;
        mVocalBuffer.clear();
        if (!mDronePlaying && stream) {
            stream->requestStop();
            stream->close();
            stream.reset();
            LOGI("Pulse Engine Stream Closed.");
        } else {
             LOGI("Pulse Engine Ticks Disabled.");
        }
    }

    void updateBpm(double bpm) {
        std::lock_guard<std::recursive_mutex> lock(mLock);
        mBpm = bpm;
        if (stream) {
            updatePhaseIncrement();
        }
        LOGI("BPM Updated: %f", mBpm);
    }

    void startDrone(double freq) {
        std::lock_guard<std::recursive_mutex> lock(mLock);
        mDroneFreq = freq;
        mDronePhase = 0.0;
        
        if (!stream) {
            start(mBpm);
            mIsPlaying = false; 
        } else {
             mSampleRate = stream->getSampleRate();
        }
        
        mDronePhaseIncrement = mDroneFreq / (double)mSampleRate;
        mTargetDroneGain = 0.4f; // Standard gain
        mDronePlaying = true;
        LOGI("Drone Engine Started: FREQ %f", mDroneFreq);
    }

    void stopDrone() {
        std::lock_guard<std::recursive_mutex> lock(mLock);
        mTargetDroneGain = 0.0f;
        // mDronePlaying will be set to false by the audio thread once gain reaches 0
        LOGI("Drone Engine Stopping (Ramping Down)...");
    }

    double writeVocalData(const int16_t* data, int32_t numSamples) {
        if (numSamples <= 0) return 0.0;
        // Optimization: Accumulate as int64_t to avoid per-sample conversion and division
        int64_t sumSq = 0;
        for (int i = 0; i < numSamples; ++i) {
            int32_t s = data[i];
            sumSq += (int64_t)s * s;
        }
        // Normalize only once after accumulation
        // (sumSq / numSamples) / (32768.0 * 32768.0)
        double meanSq = (double)sumSq / (double)numSamples;
        double rms = sqrt(meanSq) / 32768.0;

        mVocalBuffer.write(data, numSamples);
        return rms;
    }

    void updateDroneFreq(double freq) {
        mDroneFreq = freq;
        if (stream) {
            mSampleRate = stream->getSampleRate();
            mDronePhaseIncrement = mDroneFreq / (double)mSampleRate;
        }
        LOGI("Drone Freq Updated: %f", mDroneFreq);
    }

    void clearVocalBuffer() {
        mClearVocalBuffer.store(true);
        LOGI("Vocal Buffer Purge Requested.");
    }

    void updateSignature(int signature) {
        mSignature.store(signature);
        mTickCount.store(0); // Reset count on signature change
        LOGI("Signature Updated: %d/4", signature);
    }

    DataCallbackResult onAudioReady(AudioStream *oboeStream, void *audioData, int32_t numFrames) override {
        float *floatData = (float *) audioData;
        if (!floatData) return DataCallbackResult::Stop;

        for (int i = 0; i < numFrames; ++i) {
            float sampleValue = 0.0f;

            if (mIsPlaying.load()) {
                mPhase += mPhaseIncrement;
                
                // Render a tick
                if (mPhase >= 1.0) {
                    mPhase -= 1.0;
                    mOscillatorPhase = 1.0; // Trigger tick envelope
                    
                    // Increment tick count for signature tracking
                    int currentCount = mTickCount.fetch_add(1);
                    if (currentCount >= mSignature.load() - 1) {
                        mTickCount.store(0);
                    }
                }

                if (mOscillatorPhase > 0.0) {
                    // C5 (523.25 Hz) for regular tick
                    // C6 (1046.50 Hz) for Downbeat
                    bool isDownbeat = (mTickCount.load() == 0);
                    double freq = isDownbeat ? 1046.50 : 523.25;
                    
                    mOscillatorPhase -= 0.01; // Faster decay for punch
                    if (mOscillatorPhase < 0.0) mOscillatorPhase = 0.0;

                    sampleValue += sin(mOscillatorPhase * M_PI * freq * 2.0) * (float)mOscillatorPhase * 0.8f;
                }
            }

            if (mDronePlaying.load()) {
                // Smooth Gain Ramping
                float currentGain = mDroneGain.load();
                float targetGain = mTargetDroneGain.load();
                if (currentGain < targetGain) {
                    currentGain += kGainStep;
                    if (currentGain > targetGain) currentGain = targetGain;
                } else if (currentGain > targetGain) {
                    currentGain -= kGainStep;
                    if (currentGain < targetGain) currentGain = targetGain;
                }
                mDroneGain.store(currentGain);

                if (currentGain > 0.0f) {
                    mDronePhase += mDronePhaseIncrement;
                    if (mDronePhase >= 1.0) {
                        mDronePhase -= 1.0;
                    }
                    sampleValue += sin(mDronePhase * M_PI * 2.0) * currentGain;
                } else if (targetGain == 0.0f) {
                    mDronePlaying.store(false);
                }
            }

            // Mix AI Vocal from Ring Buffer
            if (mClearVocalBuffer.load()) {
                mVocalBuffer.clear();
                mClearVocalBuffer.store(false);
            }
            
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
Java_com_example_frontend_MainActivity_updateBpm(JNIEnv* env, jobject /* this */, jdouble bpm) {
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
Java_com_example_frontend_MainActivity_updateDroneFreq(JNIEnv* env, jobject /* this */, jdouble freq) {
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
Java_com_example_frontend_MainActivity_clearVocalBuffer(JNIEnv* env, jobject /* this */) {
    engine.clearVocalBuffer();
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_frontend_MainActivity_updateSignature(JNIEnv* env, jobject /* this */, jint signature) {
    engine.updateSignature(signature);
}
