#include "waveform.h"

namespace sonora {
namespace analysis {

bool WaveformExtractor::extract(const float* pcm_samples,
                                uint32_t num_samples,
                                uint32_t channels,
                                float* out_min,
                                float* out_max,
                                float* out_rms,
                                uint32_t num_peaks) {
    if (!pcm_samples || !out_min || !out_max || !out_rms) {
        return false;
    }
    if (num_samples == 0 || channels == 0 || num_peaks == 0) {
        return false;
    }

    uint32_t num_frames = num_samples / channels;
    if (num_frames == 0) return false;

    float frames_per_peak = static_cast<float>(num_frames) / static_cast<float>(num_peaks);

    for (uint32_t p = 0; p < num_peaks; ++p) {
        uint32_t start_frame = static_cast<uint32_t>(static_cast<float>(p) * frames_per_peak);
        uint32_t end_frame = static_cast<uint32_t>(static_cast<float>(p + 1) * frames_per_peak);
        if (end_frame > num_frames) end_frame = num_frames;
        if (end_frame <= start_frame) end_frame = start_frame + 1;

        float min_val = 1.0f;
        float max_val = -1.0f;
        double sum_squares = 0.0;
        uint32_t count = 0;

        for (uint32_t frame = start_frame; frame < end_frame; ++frame) {
            float mono_sample = 0.0f;
            for (uint32_t c = 0; c < channels; ++c) {
                mono_sample += pcm_samples[frame * channels + c];
            }
            mono_sample /= static_cast<float>(channels);

            if (mono_sample < min_val) min_val = mono_sample;
            if (mono_sample > max_val) max_val = mono_sample;
            sum_squares += (mono_sample * mono_sample);
            ++count;
        }

        out_min[p] = (count > 0) ? min_val : 0.0f;
        out_max[p] = (count > 0) ? max_val : 0.0f;
        out_rms[p] = (count > 0) ? static_cast<float>(std::sqrt(sum_squares / count)) : 0.0f;
    }

    return true;
}

} // namespace analysis
} // namespace sonora
