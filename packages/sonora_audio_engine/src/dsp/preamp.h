#ifndef SONORA_PREAMP_H
#define SONORA_PREAMP_H

#include <stdint.h>
#include <cmath>
#include <algorithm>

namespace sonora {
namespace dsp {

/**
 * Preamp gain stage with smooth parameter interpolation and soft-knee limiter.
 */
class Preamp {
public:
    Preamp();

    void reset();

    void setGainDb(float gain_db);
    float getGainDb() const { return target_gain_db_; }

    void setLimiterEnabled(bool enabled) { limiter_enabled_ = enabled; }
    bool isLimiterEnabled() const { return limiter_enabled_; }

    inline float processSample(float in_sample) {
        if (transition_samples_remaining_ > 0) {
            current_linear_gain_ += delta_linear_gain_;
            --transition_samples_remaining_;
        }

        float out = in_sample * current_linear_gain_;

        if (limiter_enabled_) {
            out = applySoftLimiter(out);
        }

        return out;
    }

private:
    float applySoftLimiter(float sample) {
        constexpr float threshold = 0.95f;
        float abs_val = std::abs(sample);
        if (abs_val <= threshold) {
            return sample;
        }

        // Smooth cubic saturation above threshold
        float excess = abs_val - threshold;
        float compressed = threshold + (1.0f - threshold) * std::tanh(excess / (1.0f - threshold));
        return (sample < 0.0f) ? -compressed : compressed;
    }

    float target_gain_db_;
    float current_linear_gain_;
    float target_linear_gain_;
    float delta_linear_gain_;
    uint32_t transition_samples_remaining_;
    bool limiter_enabled_;
};

} // namespace dsp
} // namespace sonora

#endif // SONORA_PREAMP_H
