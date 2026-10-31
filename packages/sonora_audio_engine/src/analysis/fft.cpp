#include "fft.h"
#include <cmath>
#include <algorithm>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

namespace sonora {
namespace analysis {

FftAnalyzer::FftAnalyzer() {}

void FftAnalyzer::radix2Fft(std::vector<std::complex<float>>& a) {
    const size_t n = a.size();
    if (n <= 1) return;

    // Bit-reversal permutation
    for (size_t i = 1, j = 0; i < n; ++i) {
        size_t bit = n >> 1;
        for (; j & bit; bit >>= 1) {
            j ^= bit;
        }
        j ^= bit;
        if (i < j) {
            std::swap(a[i], a[j]);
        }
    }

    // Cooley-Tukey Radix-2 computation
    for (size_t len = 2; len <= n; len <<= 1) {
        float ang = static_cast<float>(-2.0 * M_PI / static_cast<double>(len));
        std::complex<float> wlen(std::cos(ang), std::sin(ang));
        for (size_t i = 0; i < n; i += len) {
            std::complex<float> w(1.0f, 0.0f);
            for (size_t j = 0; j < len / 2; ++j) {
                std::complex<float> u = a[i + j];
                std::complex<float> v = a[i + j + len / 2] * w;
                a[i + j] = u + v;
                a[i + j + len / 2] = u - v;
                w *= wlen;
            }
        }
    }
}

bool FftAnalyzer::computeFft(const float* pcm_samples,
                             uint32_t num_samples,
                             float* out_magnitudes,
                             uint32_t fft_size) {
    if (!pcm_samples || !out_magnitudes || num_samples < fft_size) {
        return false;
    }
    // Check if fft_size is power of 2
    if ((fft_size & (fft_size - 1)) != 0 || fft_size < 16) {
        return false;
    }

    std::vector<std::complex<float>> buffer(fft_size);

    // Apply Hann window and load complex vector
    for (size_t i = 0; i < fft_size; ++i) {
        float hann = 0.5f * (1.0f - std::cos(2.0f * static_cast<float>(M_PI) * static_cast<float>(i) / static_cast<float>(fft_size - 1)));
        buffer[i] = std::complex<float>(pcm_samples[i] * hann, 0.0f);
    }

    radix2Fft(buffer);

    // Convert positive frequency bins (0 to fft_size/2) to magnitude in dB
    const uint32_t half_size = fft_size / 2;
    const float norm = 2.0f / static_cast<float>(fft_size);

    for (uint32_t i = 0; i < half_size; ++i) {
        float mag = std::abs(buffer[i]) * norm;
        // Convert to dB, clamped to minimum floor of -100 dB
        float db = (mag > 1e-5f) ? (20.0f * std::log10(mag)) : -100.0f;
        out_magnitudes[i] = db;
    }

    return true;
}

bool FftAnalyzer::computeSpectrumBands(const float* magnitudes,
                                      uint32_t num_magnitudes,
                                      uint32_t sample_rate,
                                      float* out_bands,
                                      uint32_t num_bands,
                                      float min_freq,
                                      float max_freq) {
    if (!magnitudes || !out_bands || num_magnitudes == 0 || num_bands == 0) {
        return false;
    }

    float nyquist = sample_rate * 0.5f;
    min_freq = std::max(20.0f, min_freq);
    max_freq = std::min(nyquist, max_freq);
    if (min_freq >= max_freq) return false;

    float hz_per_bin = nyquist / static_cast<float>(num_magnitudes);
    float log_min = std::log10(min_freq);
    float log_max = std::log10(max_freq);
    float log_range = (log_max - log_min) / static_cast<float>(num_bands);

    for (uint32_t b = 0; b < num_bands; ++b) {
        float f_start = std::pow(10.0f, log_min + static_cast<float>(b) * log_range);
        float f_end = std::pow(10.0f, log_min + static_cast<float>(b + 1) * log_range);

        uint32_t bin_start = static_cast<uint32_t>(std::max(0.0f, f_start / hz_per_bin));
        uint32_t bin_end = static_cast<uint32_t>(std::min(static_cast<float>(num_magnitudes - 1), f_end / hz_per_bin));
        if (bin_end < bin_start) bin_end = bin_start;

        float max_db = -100.0f;
        for (uint32_t bin = bin_start; bin <= bin_end; ++bin) {
            max_db = std::max(max_db, magnitudes[bin]);
        }

        // Normalize dB (-80 dB to 0 dB) into 0.0 to 1.0 linear visual bar height
        float normalized = (max_db + 80.0f) / 80.0f;
        out_bands[b] = std::max(0.0f, std::min(normalized, 1.0f));
    }

    return true;
}

} // namespace analysis
} // namespace sonora
