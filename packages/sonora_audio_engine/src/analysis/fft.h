#ifndef SONORA_FFT_H
#define SONORA_FFT_H

#include <stdint.h>
#include <vector>
#include <complex>

namespace sonora {
namespace analysis {

/**
 * High-performance Cooley-Tukey Radix-2 Fast Fourier Transform.
 *
 * Computes frequency spectrum with Hann windowing and groups bins into
 * logarithmically spaced visualizer frequency bands.
 */
class FftAnalyzer {
public:
    FftAnalyzer();

    /**
     * Computes the FFT magnitude spectrum in decibels for an input PCM buffer.
     *
     * @param pcm_samples Float PCM input (mono or pre-mixed).
     * @param num_samples Length of pcm_samples (must be >= fft_size).
     * @param out_magnitudes Output buffer of size (fft_size / 2).
     * @param fft_size Size of FFT (must be power of two: 512, 1024, or 2048).
     * @return true on success.
     */
    static bool computeFft(const float* pcm_samples,
                           uint32_t num_samples,
                           float* out_magnitudes,
                           uint32_t fft_size);

    /**
     * Groups linear FFT frequency bins into logarithmic visualizer bands.
     *
     * @param magnitudes Array of size (fft_size / 2) with magnitudes in dB.
     * @param num_magnitudes Size of magnitudes array.
     * @param sample_rate Audio sample rate in Hz.
     * @param out_bands Array of size num_bands to receive normalized heights (0.0 to 1.0).
     * @param num_bands Number of output visualizer bands.
     * @param min_freq Lowest frequency in Hz.
     * @param max_freq Highest frequency in Hz.
     * @return true on success.
     */
    static bool computeSpectrumBands(const float* magnitudes,
                                     uint32_t num_magnitudes,
                                     uint32_t sample_rate,
                                     float* out_bands,
                                     uint32_t num_bands,
                                     float min_freq,
                                     float max_freq);

private:
    static void radix2Fft(std::vector<std::complex<float>>& data);
};

} // namespace analysis
} // namespace sonora

#endif // SONORA_FFT_H
