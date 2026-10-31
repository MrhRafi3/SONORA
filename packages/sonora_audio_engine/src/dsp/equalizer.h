#ifndef SONORA_EQUALIZER_H
#define SONORA_EQUALIZER_H

#include "biquad_filter.h"
#include <vector>
#include <memory>

namespace sonora {
namespace dsp {

/**
 * Multi-band Equalizer Filter Bank.
 *
 * Implements an arbitrary-length cascade of biquad filter stages with
 * support for standard 5-band and 10-band ISO layouts.
 */
class Equalizer {
public:
    Equalizer(float sample_rate, uint32_t channels);

    void reset();
    void setSampleRate(float sample_rate);
    float getSampleRate() const { return sample_rate_; }

    uint32_t getChannels() const { return channels_; }
    void setChannels(uint32_t channels) { channels_ = channels; }

    void setEnabled(bool enabled) { enabled_ = enabled; }
    bool isEnabled() const { return enabled_; }

    bool initStandardBands(uint32_t num_bands);
    uint32_t getBandCount() const { return static_cast<uint32_t>(bands_.size()); }

    bool configureBand(uint32_t band_index,
                       FilterType type,
                       float frequency_hz,
                       float q_factor,
                       float gain_db);

    bool setBandGain(uint32_t band_index, float gain_db);
    float getBandGain(uint32_t band_index) const;
    float getBandFrequency(uint32_t band_index) const;

    inline float processSample(float in_sample, uint32_t channel) {
        if (!enabled_) {
            return in_sample;
        }

        float sample = in_sample;
        for (auto& band : bands_) {
            sample = band.processSample(sample, channel);
        }
        return sample;
    }

private:
    float sample_rate_;
    uint32_t channels_;
    bool enabled_;
    std::vector<BiquadFilter> bands_;
};

} // namespace dsp
} // namespace sonora

#endif // SONORA_EQUALIZER_H
