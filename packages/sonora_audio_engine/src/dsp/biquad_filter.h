#ifndef SONORA_BIQUAD_FILTER_H
#define SONORA_BIQUAD_FILTER_H

#include <stdint.h>
#include <cmath>

namespace sonora {
namespace dsp {

enum class FilterType : int32_t {
    Peaking = 0,
    LowShelf = 1,
    HighShelf = 2,
    LowPass = 3,
    HighPass = 4,
    BandPass = 5,
    Notch = 6
};

/**
 * Direct Form II Transposed Biquad IIR Filter.
 *
 * Implements standard Robert Bristow-Johnson (RBJ) Audio EQ Cookbook equations
 * with per-channel state vectors and coefficient interpolation for click-free
 * parameter modulation.
 */
class BiquadFilter {
public:
    BiquadFilter();

    void reset();

    void configure(FilterType type,
                   float sample_rate,
                   float frequency_hz,
                   float q_factor,
                   float gain_db);

    void setGainDb(float gain_db);
    float getGainDb() const { return target_gain_db_; }
    float getFrequencyHz() const { return frequency_hz_; }
    float getQFactor() const { return q_factor_; }
    FilterType getType() const { return type_; }

    // Direct Form II Transposed processing
    inline float processSample(float in_sample, uint32_t channel) {
        if (channel >= 2) return in_sample;

        // Smooth coefficients toward target on channel 0 once per frame
        if (channel == 0 && transition_samples_remaining_ > 0) {
            stepCoefficients();
        }

        // y[n] = b0 * x[n] + s1
        float out = current_b0_ * in_sample + s1_[channel];

        // s1 = b1 * x[n] - a1 * y[n] + s2
        s1_[channel] = current_b1_ * in_sample - current_a1_ * out + s2_[channel];

        // s2 = b2 * x[n] - a2 * y[n]
        s2_[channel] = current_b2_ * in_sample - current_a2_ * out;

        // Anti-denormal flush to zero
        if (std::abs(s1_[channel]) < 1e-15f) s1_[channel] = 0.0f;
        if (std::abs(s2_[channel]) < 1e-15f) s2_[channel] = 0.0f;

        return out;
    }

private:
    void calculateCoefficients(float gain_db, float& b0, float& b1, float& b2, float& a1, float& a2);
    void stepCoefficients();

    FilterType type_;
    float sample_rate_;
    float frequency_hz_;
    float q_factor_;
    float target_gain_db_;

    // Current active normalized coefficients (a0 is normalized to 1.0)
    float current_b0_;
    float current_b1_;
    float current_b2_;
    float current_a1_;
    float current_a2_;

    // Target coefficients for smooth interpolation
    float target_b0_;
    float target_b1_;
    float target_b2_;
    float target_a1_;
    float target_a2_;

    // Linear delta per sample for de-zippering
    float delta_b0_;
    float delta_b1_;
    float delta_b2_;
    float delta_a1_;
    float delta_a2_;
    uint32_t transition_samples_remaining_;

    // Filter states for up to 2 channels (Direct Form II Transposed delays)
    float s1_[2];
    float s2_[2];
};

} // namespace dsp
} // namespace sonora

#endif // SONORA_BIQUAD_FILTER_H
