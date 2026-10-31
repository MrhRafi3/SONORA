#ifndef SONORA_WAVEFORM_H
#define SONORA_WAVEFORM_H

#include <stdint.h>
#include <cmath>
#include <algorithm>

namespace sonora {
namespace analysis {

class WaveformExtractor {
public:
    static bool extract(const float* pcm_samples,
                        uint32_t num_samples,
                        uint32_t channels,
                        float* out_min,
                        float* out_max,
                        float* out_rms,
                        uint32_t num_peaks);
};

} // namespace analysis
} // namespace sonora

#endif // SONORA_WAVEFORM_H
