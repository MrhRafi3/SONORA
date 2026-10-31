#include "sonora_audio_engine.h"
#include "dsp/biquad_filter.h"
#include "dsp/equalizer.h"
#include "dsp/preamp.h"
#include "analysis/fft.h"
#include "analysis/waveform.h"

#include <mutex>
#include <memory>
#include <cstring>

static const char* kSonoraEngineVersion = "1.0.0-phase06";

struct SonoraEngine {
    SonoraEngine(uint32_t s_rate, uint32_t ch)
        : sample_rate(s_rate),
          channels(ch),
          equalizer(static_cast<float>(s_rate), ch) {}

    uint32_t sample_rate;
    uint32_t channels;
    sonora::dsp::Preamp preamp;
    sonora::dsp::Equalizer equalizer;
    std::mutex process_mutex;
};

extern "C" {

SonoraEngine* sonora_engine_create(uint32_t sample_rate, uint32_t channels) {
    if (sample_rate < 8000 || sample_rate > 384000 || channels == 0 || channels > 2) {
        return nullptr;
    }
    try {
        return new SonoraEngine(sample_rate, channels);
    } catch (...) {
        return nullptr;
    }
}

void sonora_engine_destroy(SonoraEngine* engine) {
    if (engine) {
        delete engine;
    }
}

int32_t sonora_engine_reset(SonoraEngine* engine) {
    if (!engine) return SONORA_ERROR_NULL_POINTER;
    std::lock_guard<std::mutex> lock(engine->process_mutex);
    engine->preamp.reset();
    engine->equalizer.reset();
    return SONORA_OK;
}

int32_t sonora_engine_set_sample_rate(SonoraEngine* engine, uint32_t sample_rate) {
    if (!engine) return SONORA_ERROR_NULL_POINTER;
    if (sample_rate < 8000 || sample_rate > 384000) return SONORA_ERROR_INVALID_ARGUMENT;

    std::lock_guard<std::mutex> lock(engine->process_mutex);
    engine->sample_rate = sample_rate;
    engine->equalizer.setSampleRate(static_cast<float>(sample_rate));
    return SONORA_OK;
}

uint32_t sonora_engine_get_sample_rate(const SonoraEngine* engine) {
    if (!engine) return 0;
    return engine->sample_rate;
}

uint32_t sonora_engine_get_channel_count(const SonoraEngine* engine) {
    if (!engine) return 0;
    return engine->channels;
}

int32_t sonora_engine_set_preamp_gain(SonoraEngine* engine, float gain_db) {
    if (!engine) return SONORA_ERROR_NULL_POINTER;
    std::lock_guard<std::mutex> lock(engine->process_mutex);
    engine->preamp.setGainDb(gain_db);
    return SONORA_OK;
}

float sonora_engine_get_preamp_gain(const SonoraEngine* engine) {
    if (!engine) return 0.0f;
    return engine->preamp.getGainDb();
}

int32_t sonora_engine_set_limiter_enabled(SonoraEngine* engine, int32_t enabled) {
    if (!engine) return SONORA_ERROR_NULL_POINTER;
    std::lock_guard<std::mutex> lock(engine->process_mutex);
    engine->preamp.setLimiterEnabled(enabled != 0);
    return SONORA_OK;
}

int32_t sonora_engine_is_limiter_enabled(const SonoraEngine* engine) {
    if (!engine) return 0;
    return engine->preamp.isLimiterEnabled() ? 1 : 0;
}

int32_t sonora_engine_set_eq_enabled(SonoraEngine* engine, int32_t enabled) {
    if (!engine) return SONORA_ERROR_NULL_POINTER;
    std::lock_guard<std::mutex> lock(engine->process_mutex);
    engine->equalizer.setEnabled(enabled != 0);
    return SONORA_OK;
}

int32_t sonora_engine_is_eq_enabled(const SonoraEngine* engine) {
    if (!engine) return 0;
    return engine->equalizer.isEnabled() ? 1 : 0;
}

int32_t sonora_engine_init_standard_eq(SonoraEngine* engine, uint32_t num_bands) {
    if (!engine) return SONORA_ERROR_NULL_POINTER;
    std::lock_guard<std::mutex> lock(engine->process_mutex);
    return engine->equalizer.initStandardBands(num_bands) ? SONORA_OK : SONORA_ERROR_INVALID_ARGUMENT;
}

uint32_t sonora_engine_get_eq_band_count(const SonoraEngine* engine) {
    if (!engine) return 0;
    return engine->equalizer.getBandCount();
}

int32_t sonora_engine_configure_eq_band(SonoraEngine* engine,
                                        uint32_t band_index,
                                        int32_t filter_type,
                                        float frequency_hz,
                                        float q_factor,
                                        float gain_db) {
    if (!engine) return SONORA_ERROR_NULL_POINTER;
    std::lock_guard<std::mutex> lock(engine->process_mutex);
    bool ok = engine->equalizer.configureBand(
        band_index,
        static_cast<sonora::dsp::FilterType>(filter_type),
        frequency_hz,
        q_factor,
        gain_db
    );
    return ok ? SONORA_OK : SONORA_ERROR_INVALID_ARGUMENT;
}

int32_t sonora_engine_set_eq_band_gain(SonoraEngine* engine,
                                       uint32_t band_index,
                                       float gain_db) {
    if (!engine) return SONORA_ERROR_NULL_POINTER;
    std::lock_guard<std::mutex> lock(engine->process_mutex);
    return engine->equalizer.setBandGain(band_index, gain_db) ? SONORA_OK : SONORA_ERROR_INVALID_ARGUMENT;
}

float sonora_engine_get_eq_band_gain(const SonoraEngine* engine, uint32_t band_index) {
    if (!engine) return 0.0f;
    return engine->equalizer.getBandGain(band_index);
}

float sonora_engine_get_eq_band_frequency(const SonoraEngine* engine, uint32_t band_index) {
    if (!engine) return 0.0f;
    return engine->equalizer.getBandFrequency(band_index);
}

int32_t sonora_engine_process_interleaved(SonoraEngine* engine,
                                          const float* in_samples,
                                          float* out_samples,
                                          uint32_t num_frames) {
    if (!engine || !in_samples || !out_samples) return SONORA_ERROR_NULL_POINTER;
    if (num_frames == 0) return SONORA_OK;

    std::lock_guard<std::mutex> lock(engine->process_mutex);
    const uint32_t channels = engine->channels;

    for (uint32_t frame = 0; frame < num_frames; ++frame) {
        for (uint32_t c = 0; c < channels; ++c) {
            uint32_t idx = frame * channels + c;
            float sample = in_samples[idx];

            // 1. Equalizer Filter Bank
            sample = engine->equalizer.processSample(sample, c);

            // 2. Preamp Gain Stage & Soft Limiter
            sample = engine->preamp.processSample(sample);

            out_samples[idx] = sample;
        }
    }
    return SONORA_OK;
}

int32_t sonora_engine_process_inplace(SonoraEngine* engine,
                                      float* samples,
                                      uint32_t num_frames) {
    return sonora_engine_process_interleaved(engine, samples, samples, num_frames);
}

int32_t sonora_analysis_compute_fft(const float* pcm_samples,
                                    uint32_t num_samples,
                                    float* out_magnitudes,
                                    uint32_t fft_size) {
    if (!pcm_samples || !out_magnitudes) return SONORA_ERROR_NULL_POINTER;
    bool ok = sonora::analysis::FftAnalyzer::computeFft(pcm_samples, num_samples, out_magnitudes, fft_size);
    return ok ? SONORA_OK : SONORA_ERROR_INVALID_ARGUMENT;
}

int32_t sonora_analysis_compute_spectrum_bands(const float* magnitudes,
                                               uint32_t num_magnitudes,
                                               uint32_t sample_rate,
                                               float* out_bands,
                                               uint32_t num_bands,
                                               float min_freq,
                                               float max_freq) {
    if (!magnitudes || !out_bands) return SONORA_ERROR_NULL_POINTER;
    bool ok = sonora::analysis::FftAnalyzer::computeSpectrumBands(
        magnitudes, num_magnitudes, sample_rate, out_bands, num_bands, min_freq, max_freq
    );
    return ok ? SONORA_OK : SONORA_ERROR_INVALID_ARGUMENT;
}

int32_t sonora_analysis_extract_waveform(const float* pcm_samples,
                                         uint32_t num_samples,
                                         uint32_t channels,
                                         float* out_min,
                                         float* out_max,
                                         float* out_rms,
                                         uint32_t num_peaks) {
    if (!pcm_samples || !out_min || !out_max || !out_rms) return SONORA_ERROR_NULL_POINTER;
    bool ok = sonora::analysis::WaveformExtractor::extract(
        pcm_samples, num_samples, channels, out_min, out_max, out_rms, num_peaks
    );
    return ok ? SONORA_OK : SONORA_ERROR_INVALID_ARGUMENT;
}

const char* sonora_engine_get_version(void) {
    return kSonoraEngineVersion;
}

} // extern "C"
