#ifndef SONORA_AUDIO_ENGINE_H
#define SONORA_AUDIO_ENGINE_H

#include <stdint.h>
#include <stddef.h>

#if defined(_WIN32)
    #define SONORA_EXPORT __declspec(dllexport)
#else
    #define SONORA_EXPORT __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

/* =========================================================================
 * Status & Error Codes
 * ========================================================================= */
#define SONORA_OK                         0
#define SONORA_ERROR_INVALID_ARGUMENT    -1
#define SONORA_ERROR_NULL_POINTER        -2
#define SONORA_ERROR_OUT_OF_MEMORY       -3
#define SONORA_ERROR_UNSUPPORTED         -4
#define SONORA_ERROR_INVALID_STATE       -5

/* =========================================================================
 * Filter Topologies
 * ========================================================================= */
#define SONORA_FILTER_PEAKING             0
#define SONORA_FILTER_LOW_SHELF           1
#define SONORA_FILTER_HIGH_SHELF          2
#define SONORA_FILTER_LOW_PASS            3
#define SONORA_FILTER_HIGH_PASS           4
#define SONORA_FILTER_BAND_PASS           5
#define SONORA_FILTER_NOTCH               6

/* Opaque Engine Handle */
typedef struct SonoraEngine SonoraEngine;

/* =========================================================================
 * Engine Lifecycle & Configuration
 * ========================================================================= */

/**
 * Creates and initializes a new Sonora native audio engine instance.
 *
 * @param sample_rate Audio sample rate in Hz (e.g., 44100, 48000, 96000, 192000).
 * @param channels Number of interleaved audio channels (1 = Mono, 2 = Stereo).
 * @return Pointer to SonoraEngine instance, or NULL on allocation failure.
 */
SONORA_EXPORT SonoraEngine* sonora_engine_create(uint32_t sample_rate, uint32_t channels);

/**
 * Destroys an existing SonoraEngine instance and releases all native resources.
 *
 * @param engine Pointer to the engine instance to destroy. Safe to call with NULL.
 */
SONORA_EXPORT void sonora_engine_destroy(SonoraEngine* engine);

/**
 * Resets all internal filter states and history buffers to zero (silence).
 *
 * @param engine Pointer to active engine instance.
 * @return SONORA_OK on success, or negative error code.
 */
SONORA_EXPORT int32_t sonora_engine_reset(SonoraEngine* engine);

/**
 * Updates the engine sample rate and recalculates all active filter coefficients.
 *
 * @param engine Pointer to active engine instance.
 * @param sample_rate New sample rate in Hz.
 * @return SONORA_OK on success, or negative error code.
 */
SONORA_EXPORT int32_t sonora_engine_set_sample_rate(SonoraEngine* engine, uint32_t sample_rate);

/**
 * Returns current sample rate in Hz.
 */
SONORA_EXPORT uint32_t sonora_engine_get_sample_rate(const SonoraEngine* engine);

/**
 * Returns current channel count (1 or 2).
 */
SONORA_EXPORT uint32_t sonora_engine_get_channel_count(const SonoraEngine* engine);

/* =========================================================================
 * Preamp Gain & Limiter Controls
 * ========================================================================= */

/**
 * Sets the master preamp gain applied before filter stages.
 *
 * @param engine Pointer to active engine instance.
 * @param gain_db Gain in decibels (typically -12.0 dB to +12.0 dB).
 * @return SONORA_OK on success, or negative error code.
 */
SONORA_EXPORT int32_t sonora_engine_set_preamp_gain(SonoraEngine* engine, float gain_db);

/**
 * Returns the current preamp gain in dB.
 */
SONORA_EXPORT float sonora_engine_get_preamp_gain(const SonoraEngine* engine);

/**
 * Enables or disables the soft-knee output limiter preventing digital clipping.
 *
 * @param engine Pointer to active engine instance.
 * @param enabled 1 to enable, 0 to bypass.
 * @return SONORA_OK on success, or negative error code.
 */
SONORA_EXPORT int32_t sonora_engine_set_limiter_enabled(SonoraEngine* engine, int32_t enabled);

/**
 * Returns whether the soft limiter is currently enabled (1) or bypassed (0).
 */
SONORA_EXPORT int32_t sonora_engine_is_limiter_enabled(const SonoraEngine* engine);

/* =========================================================================
 * Equalizer Filter Bank Configuration
 * ========================================================================= */

/**
 * Globally enables or bypasses the equalizer filter bank.
 *
 * @param engine Pointer to active engine instance.
 * @param enabled 1 to enable EQ processing, 0 to bypass.
 * @return SONORA_OK on success, or negative error code.
 */
SONORA_EXPORT int32_t sonora_engine_set_eq_enabled(SonoraEngine* engine, int32_t enabled);

/**
 * Returns whether the equalizer filter bank is enabled (1) or bypassed (0).
 */
SONORA_EXPORT int32_t sonora_engine_is_eq_enabled(const SonoraEngine* engine);

/**
 * Initializes a standard graphic EQ layout with ISO standard center frequencies.
 *
 * @param engine Pointer to active engine instance.
 * @param num_bands Supported values: 5 (60Hz, 230Hz, 910Hz, 3.6kHz, 14kHz)
 *                  or 10 (31Hz, 62Hz, 125Hz, 250Hz, 500Hz, 1kHz, 2kHz, 4kHz, 8kHz, 16kHz).
 * @return SONORA_OK on success, or negative error code.
 */
SONORA_EXPORT int32_t sonora_engine_init_standard_eq(SonoraEngine* engine, uint32_t num_bands);

/**
 * Returns the number of configured bands in the equalizer filter bank.
 */
SONORA_EXPORT uint32_t sonora_engine_get_eq_band_count(const SonoraEngine* engine);

/**
 * Configures an individual EQ band's topology and acoustic parameters.
 *
 * @param engine Pointer to active engine instance.
 * @param band_index Zero-based index of band (0 <= band_index < band_count).
 * @param filter_type Topology code (SONORA_FILTER_PEAKING, etc.).
 * @param frequency_hz Center frequency in Hz (20.0 to sample_rate * 0.49).
 * @param q_factor Quality factor Q (0.1 to 10.0, standard Q = 1.414).
 * @param gain_db Band boost/cut in dB (-12.0 to +12.0 dB).
 * @return SONORA_OK on success, or negative error code.
 */
SONORA_EXPORT int32_t sonora_engine_configure_eq_band(SonoraEngine* engine,
                                                      uint32_t band_index,
                                                      int32_t filter_type,
                                                      float frequency_hz,
                                                      float q_factor,
                                                      float gain_db);

/**
 * Adjusts an existing EQ band's gain with smooth parameter de-zippering.
 *
 * @param engine Pointer to active engine instance.
 * @param band_index Zero-based index of band.
 * @param gain_db Target gain in dB.
 * @return SONORA_OK on success, or negative error code.
 */
SONORA_EXPORT int32_t sonora_engine_set_eq_band_gain(SonoraEngine* engine,
                                                     uint32_t band_index,
                                                     float gain_db);

/**
 * Returns the configured gain of a specific EQ band in dB.
 */
SONORA_EXPORT float sonora_engine_get_eq_band_gain(const SonoraEngine* engine,
                                                   uint32_t band_index);

/**
 * Returns the center frequency of a specific EQ band in Hz.
 */
SONORA_EXPORT float sonora_engine_get_eq_band_frequency(const SonoraEngine* engine,
                                                        uint32_t band_index);

/* =========================================================================
 * Real-Time Audio Buffer Processing
 * ========================================================================= */

/**
 * Processes interleaved 32-bit floating point PCM audio from input to output buffer.
 *
 * @param engine Pointer to active engine instance.
 * @param in_samples Pointer to interleaved input samples (num_frames * channels).
 * @param out_samples Pointer to interleaved output samples (num_frames * channels).
 * @param num_frames Number of audio frames to process.
 * @return SONORA_OK on success, or negative error code.
 */
SONORA_EXPORT int32_t sonora_engine_process_interleaved(SonoraEngine* engine,
                                                        const float* in_samples,
                                                        float* out_samples,
                                                        uint32_t num_frames);

/**
 * Processes interleaved 32-bit floating point PCM audio in-place.
 *
 * @param engine Pointer to active engine instance.
 * @param samples Pointer to buffer modified in-place (num_frames * channels).
 * @param num_frames Number of audio frames to process.
 * @return SONORA_OK on success, or negative error code.
 */
SONORA_EXPORT int32_t sonora_engine_process_inplace(SonoraEngine* engine,
                                                    float* samples,
                                                    uint32_t num_frames);

/* =========================================================================
 * Audio Analysis & Visualization Algorithms
 * ========================================================================= */

/**
 * Computes the normalized magnitude frequency spectrum of PCM samples using
 * a Cooley-Tukey Radix-2 FFT with a pre-applied Hann window.
 *
 * @param pcm_samples Pointer to mono or downmixed float PCM audio samples.
 * @param num_samples Input buffer length (must be >= fft_size).
 * @param out_magnitudes Output buffer for (fft_size / 2) positive frequency magnitudes in dB.
 * @param fft_size FFT window size (must be power of two: 512, 1024, or 2048).
 * @return SONORA_OK on success, or negative error code.
 */
SONORA_EXPORT int32_t sonora_analysis_compute_fft(const float* pcm_samples,
                                                  uint32_t num_samples,
                                                  float* out_magnitudes,
                                                  uint32_t fft_size);

/**
 * Groups an FFT magnitude spectrum into logarithmic frequency visualizer bands.
 *
 * @param magnitudes Input magnitude array from sonora_analysis_compute_fft (fft_size / 2).
 * @param num_magnitudes Size of magnitude array (fft_size / 2).
 * @param sample_rate Audio sample rate in Hz.
 * @param out_bands Output buffer for visualizer band heights (normalized 0.0 to 1.0).
 * @param num_bands Number of visualizer bands requested (e.g. 16, 32, 64).
 * @param min_freq Lowest frequency in Hz (e.g., 20.0 Hz).
 * @param max_freq Highest frequency in Hz (e.g., 20000.0 Hz).
 * @return SONORA_OK on success, or negative error code.
 */
SONORA_EXPORT int32_t sonora_analysis_compute_spectrum_bands(const float* magnitudes,
                                                             uint32_t num_magnitudes,
                                                             uint32_t sample_rate,
                                                             float* out_bands,
                                                             uint32_t num_bands,
                                                             float min_freq,
                                                             float max_freq);

/**
 * Extracts visual waveform peak and RMS energy vectors across an audio buffer.
 *
 * @param pcm_samples Interleaved input float PCM samples.
 * @param num_samples Total sample count (num_frames * channels).
 * @param channels Number of channels (1 or 2).
 * @param out_min Output buffer for minimum sample values per block (num_peaks elements).
 * @param out_max Output buffer for maximum sample values per block (num_peaks elements).
 * @param out_rms Output buffer for RMS energy per block (num_peaks elements).
 * @param num_peaks Number of visual peak blocks requested.
 * @return SONORA_OK on success, or negative error code.
 */
SONORA_EXPORT int32_t sonora_analysis_extract_waveform(const float* pcm_samples,
                                                       uint32_t num_samples,
                                                       uint32_t channels,
                                                       float* out_min,
                                                       float* out_max,
                                                       float* out_rms,
                                                       uint32_t num_peaks);

/* =========================================================================
 * Version & Diagnostics
 * ========================================================================= */

/**
 * Returns human-readable engine semantic version string (e.g. "1.0.0-phase06").
 */
SONORA_EXPORT const char* sonora_engine_get_version(void);

#ifdef __cplusplus
}
#endif

#endif /* SONORA_AUDIO_ENGINE_H */
