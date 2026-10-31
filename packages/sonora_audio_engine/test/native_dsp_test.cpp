#include "sonora_audio_engine.h"
#include <iostream>
#include <vector>
#include <cmath>
#include <chrono>
#include <cassert>
#include <iomanip>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// Test utilities
static std::vector<float> generateSineWave(float frequency, float sample_rate, uint32_t num_frames, uint32_t channels, float amplitude = 0.5f) {
    std::vector<float> buffer(num_frames * channels);
    for (uint32_t i = 0; i < num_frames; ++i) {
        float sample = amplitude * std::sin(2.0f * static_cast<float>(M_PI) * frequency * static_cast<float>(i) / sample_rate);
        for (uint32_t ch = 0; ch < channels; ++ch) {
            buffer[i * channels + ch] = sample;
        }
    }
    return buffer;
}

static float calculateRms(const float* buffer, uint32_t num_frames, uint32_t channels, uint32_t channel = 0) {
    double sum_sq = 0.0;
    for (uint32_t i = 0; i < num_frames; ++i) {
        float sample = buffer[i * channels + channel];
        sum_sq += sample * sample;
    }
    return static_cast<float>(std::sqrt(sum_sq / num_frames));
}

static float amplitudeToDb(float amp) {
    if (amp <= 1e-9f) return -180.0f;
    return 20.0f * std::log10(amp);
}

void test_engine_lifecycle_and_defaults() {
    std::cout << "[TEST] test_engine_lifecycle_and_defaults... " << std::flush;

    SonoraEngine* engine = sonora_engine_create(48000, 2);
    assert(engine != nullptr);

    uint32_t sr = sonora_engine_get_sample_rate(engine);
    assert(sr == 48000);

    uint32_t ch = sonora_engine_get_channel_count(engine);
    assert(ch == 2);

    float preamp = sonora_engine_get_preamp_gain(engine);
    assert(std::abs(preamp - 0.0f) < 0.01f);

    int32_t limiter = sonora_engine_is_limiter_enabled(engine);
    assert(limiter == 1);

    int32_t eq = sonora_engine_is_eq_enabled(engine);
    assert(eq == 1);

    uint32_t bands = sonora_engine_get_eq_band_count(engine);
    assert(bands == 10);

    // Test parameter modification
    sonora_engine_set_preamp_gain(engine, 3.5f);
    preamp = sonora_engine_get_preamp_gain(engine);
    assert(std::abs(preamp - 3.5f) < 0.01f);

    sonora_engine_set_limiter_enabled(engine, 0);
    limiter = sonora_engine_is_limiter_enabled(engine);
    assert(limiter == 0);

    sonora_engine_destroy(engine);
    std::cout << "PASSED" << std::endl;
}

void test_eq_frequency_response() {
    std::cout << "[TEST] test_eq_frequency_response... " << std::flush;

    const float sample_rate = 48000.0f;
    const uint32_t channels = 2;
    const uint32_t num_frames = 48000; // 1 second of audio

    SonoraEngine* engine = sonora_engine_create(48000, channels);
    assert(engine != nullptr);
    sonora_engine_init_standard_eq(engine, 10);

    // Band 5 is 1000 Hz in standard 10-band ISO
    float freq = sonora_engine_get_eq_band_frequency(engine, 5);
    assert(std::abs(freq - 1000.0f) < 1.0f);

    // 1. Generate 1000 Hz sine wave
    auto input_clean = generateSineWave(1000.0f, sample_rate, num_frames, channels, 0.2f);
    float input_rms = calculateRms(input_clean.data(), num_frames, channels);

    // 2. Process flat (0 dB)
    std::vector<float> output_flat(input_clean.size());
    sonora_engine_process_interleaved(engine, input_clean.data(), output_flat.data(), num_frames);
    float flat_rms = calculateRms(output_flat.data(), num_frames, channels);
    assert(std::abs(flat_rms - input_rms) < 0.005f); // Unity gain

    // 3. Boost 1000 Hz by +6.0 dB
    sonora_engine_reset(engine);
    sonora_engine_set_eq_band_gain(engine, 5, 6.0f);
    std::vector<float> output_boost(input_clean.size());
    sonora_engine_process_interleaved(engine, input_clean.data(), output_boost.data(), num_frames);
    // Discard initial 1000 frames for filter settle / de-zippering
    float boost_rms = calculateRms(output_boost.data() + 1000 * channels, num_frames - 1000, channels);
    float gain_db_measured = amplitudeToDb(boost_rms / input_rms);
    assert(std::abs(gain_db_measured - 6.0f) < 0.3f); // Within 0.3 dB of target

    // 4. Cut 1000 Hz by -6.0 dB
    sonora_engine_reset(engine);
    sonora_engine_set_eq_band_gain(engine, 5, -6.0f);
    std::vector<float> output_cut(input_clean.size());
    sonora_engine_process_interleaved(engine, input_clean.data(), output_cut.data(), num_frames);
    float cut_rms = calculateRms(output_cut.data() + 1000 * channels, num_frames - 1000, channels);
    float cut_db_measured = amplitudeToDb(cut_rms / input_rms);
    assert(std::abs(cut_db_measured - (-6.0f)) < 0.3f); // Within 0.3 dB of target

    sonora_engine_destroy(engine);
    std::cout << "PASSED (Boost: " << std::fixed << std::setprecision(2) << gain_db_measured
              << " dB, Cut: " << cut_db_measured << " dB)" << std::endl;
}

void test_preamp_and_limiter() {
    std::cout << "[TEST] test_preamp_and_limiter... " << std::flush;

    const float sample_rate = 48000.0f;
    const uint32_t channels = 2;
    const uint32_t num_frames = 4800; // 100ms

    SonoraEngine* engine = sonora_engine_create(48000, channels);
    assert(engine != nullptr);
    sonora_engine_set_eq_enabled(engine, 0); // Bypass EQ to test preamp alone

    // Test +6 dB preamp gain with small input
    sonora_engine_set_preamp_gain(engine, 6.0206f); // Exactly 2.0x linear
    auto input = generateSineWave(440.0f, sample_rate, num_frames, channels, 0.1f);
    std::vector<float> output(input.size());
    sonora_engine_process_interleaved(engine, input.data(), output.data(), num_frames);
    float in_rms = calculateRms(input.data(), num_frames, channels);
    float out_rms = calculateRms(output.data(), num_frames, channels);
    assert(std::abs(out_rms / in_rms - 2.0f) < 0.05f);

    // Test limiter with hot signal (amplitude 2.5f)
    sonora_engine_set_preamp_gain(engine, 0.0f);
    sonora_engine_set_limiter_enabled(engine, 1);
    auto hot_input = generateSineWave(440.0f, sample_rate, num_frames, channels, 2.5f);
    std::vector<float> limited_output(hot_input.size());
    sonora_engine_process_interleaved(engine, hot_input.data(), limited_output.data(), num_frames);

    float max_peak = 0.0f;
    for (float s : limited_output) {
        assert(!std::isnan(s) && !std::isinf(s));
        if (std::abs(s) > max_peak) max_peak = std::abs(s);
    }
    // Max peak must not exceed 1.0f with limiter enabled
    assert(max_peak <= 1.0001f);
    assert(max_peak > 0.9f); // Signal was indeed limited, not zeroed

    sonora_engine_destroy(engine);
    std::cout << "PASSED (Max limited peak: " << max_peak << ")" << std::endl;
}

void test_fft_analysis() {
    std::cout << "[TEST] test_fft_analysis... " << std::flush;

    const float sample_rate = 48000.0f;
    const uint32_t fft_size = 1024;
    const float test_freq = 1875.0f; // Exactly bin 40: 1875 * 1024 / 48000 = 40

    // Pure mono sine wave for 1024 samples
    std::vector<float> signal(fft_size);
    for (uint32_t i = 0; i < fft_size; ++i) {
        signal[i] = std::sin(2.0f * static_cast<float>(M_PI) * test_freq * static_cast<float>(i) / sample_rate);
    }

    std::vector<float> magnitudes(fft_size / 2);
    int32_t res = sonora_analysis_compute_fft(signal.data(), fft_size, magnitudes.data(), fft_size);
    assert(res == SONORA_OK);

    // Find peak bin
    uint32_t peak_bin = 0;
    float peak_mag = -999.0f;
    for (uint32_t i = 0; i < fft_size / 2; ++i) {
        if (magnitudes[i] > peak_mag) {
            peak_mag = magnitudes[i];
            peak_bin = i;
        }
    }
    // Peak bin should be exactly bin 40 (+/- 1 bin due to windowing leakage)
    assert(peak_bin >= 39 && peak_bin <= 41);

    // Test spectrum band aggregation (e.g. 16 bands)
    const uint32_t num_bands = 16;
    std::vector<float> band_energies(num_bands);
    res = sonora_analysis_compute_spectrum_bands(
        magnitudes.data(), fft_size / 2, static_cast<uint32_t>(sample_rate),
        band_energies.data(), num_bands, 20.0f, 20000.0f
    );
    assert(res == SONORA_OK);

    // Find dominant band
    uint32_t max_band = 0;
    float max_band_energy = 0.0f;
    for (uint32_t b = 0; b < num_bands; ++b) {
        if (band_energies[b] > max_band_energy) {
            max_band_energy = band_energies[b];
            max_band = b;
        }
    }
    // Frequency 1875 Hz in a log range 20Hz-20kHz should peak in the upper-mid bands
    assert(max_band >= 8 && max_band <= 12);

    std::cout << "PASSED (Peak bin: " << peak_bin << " at " << (peak_bin * sample_rate / fft_size) << " Hz)" << std::endl;
}

void test_waveform_extraction() {
    std::cout << "[TEST] test_waveform_extraction... " << std::flush;

    const uint32_t num_frames = 10000;
    const uint32_t channels = 2;
    const uint32_t num_chunks = 100;

    // 5000 Hz has ~10 full periods per 100-frame chunk, ensuring each chunk captures the full peak/trough
    auto signal = generateSineWave(5000.0f, 48000.0f, num_frames, channels, 0.75f);

    std::vector<float> min_vals(num_chunks);
    std::vector<float> max_vals(num_chunks);
    std::vector<float> rms_vals(num_chunks);

    int32_t res = sonora_analysis_extract_waveform(
        signal.data(), num_frames * channels, channels,
        min_vals.data(), max_vals.data(), rms_vals.data(), num_chunks
    );
    assert(res == SONORA_OK);

    // Verify chunk statistics
    for (uint32_t c = 0; c < num_chunks; ++c) {
        assert(min_vals[c] >= -0.76f && min_vals[c] <= -0.70f);
        assert(max_vals[c] >= 0.70f && max_vals[c] <= 0.76f);
        assert(rms_vals[c] >= 0.50f && rms_vals[c] <= 0.56f); // 0.75 / sqrt(2) ~= 0.5303
    }

    std::cout << "PASSED (100 chunks, Min: " << min_vals[0] << ", Max: " << max_vals[0] << ", RMS: " << rms_vals[0] << ")" << std::endl;
}

void test_performance_benchmark() {
    std::cout << "[BENCHMARK] test_performance_benchmark... " << std::flush;

    const float sample_rate = 48000.0f;
    const uint32_t channels = 2;
    const uint32_t buffer_size = 1024;
    const uint32_t iterations = 5000; // 5000 buffers * 1024 = 5,120,000 stereo frames = 106.67 seconds of audio

    SonoraEngine* engine = sonora_engine_create(48000, channels);
    assert(engine != nullptr);
    sonora_engine_init_standard_eq(engine, 10);
    // Apply realistic EQ curve
    for (uint32_t b = 0; b < 10; ++b) {
        sonora_engine_set_eq_band_gain(engine, b, (b % 2 == 0) ? 3.0f : -2.0f);
    }
    sonora_engine_set_preamp_gain(engine, 1.5f);
    sonora_engine_set_limiter_enabled(engine, 1);

    std::vector<float> in_buf = generateSineWave(440.0f, sample_rate, buffer_size, channels, 0.4f);
    std::vector<float> out_buf(buffer_size * channels);

    auto start_time = std::chrono::high_resolution_clock::now();

    for (uint32_t i = 0; i < iterations; ++i) {
        sonora_engine_process_interleaved(engine, in_buf.data(), out_buf.data(), buffer_size);
    }

    auto end_time = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double, std::milli> elapsed_ms = end_time - start_time;

    double total_ms = elapsed_ms.count();
    double ms_per_buffer = total_ms / iterations;
    double simulated_audio_seconds = (static_cast<double>(iterations) * buffer_size) / sample_rate;
    double realtime_factor = (simulated_audio_seconds * 1000.0) / total_ms;

    std::cout << "DONE" << std::endl;
    std::cout << "  Iterations: " << iterations << " buffers of " << buffer_size << " stereo frames" << std::endl;
    std::cout << "  Simulated audio: " << std::fixed << std::setprecision(2) << simulated_audio_seconds << " seconds" << std::endl;
    std::cout << "  Total compute time: " << total_ms << " ms" << std::endl;
    std::cout << "  Average time per 1024-frame buffer: " << std::setprecision(4) << ms_per_buffer << " ms (Budget: 21.33 ms)" << std::endl;
    std::cout << "  Real-time speedup factor: " << std::setprecision(1) << realtime_factor << "x faster than real-time!" << std::endl;

    // Must be at least 50x faster than real-time
    assert(realtime_factor > 50.0);

    sonora_engine_destroy(engine);
}

int main() {
    std::cout << "==================================================" << std::endl;
    std::cout << " SONORA Native C++ Audio Engine Unit Test & Benchmark" << std::endl;
    std::cout << " Version: " << sonora_engine_get_version() << std::endl;
    std::cout << "==================================================" << std::endl;

    test_engine_lifecycle_and_defaults();
    test_eq_frequency_response();
    test_preamp_and_limiter();
    test_fft_analysis();
    test_waveform_extraction();
    test_performance_benchmark();

    std::cout << "==================================================" << std::endl;
    std::cout << " ALL NATIVE C++ TESTS & BENCHMARKS PASSED (100%)" << std::endl;
    std::cout << "==================================================" << std::endl;
    return 0;
}
