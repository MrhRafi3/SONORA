#include "equalizer.h"

namespace sonora {
namespace dsp {

Equalizer::Equalizer(float sample_rate, uint32_t channels)
    : sample_rate_(sample_rate),
      channels_(channels),
      enabled_(true) {
    // Default to 10-band ISO standard
    initStandardBands(10);
}

void Equalizer::reset() {
    for (auto& band : bands_) {
        band.reset();
    }
}

void Equalizer::setSampleRate(float sample_rate) {
    sample_rate_ = sample_rate;
    // Reconfigure all existing bands with new sample rate
    for (size_t i = 0; i < bands_.size(); ++i) {
        bands_[i].configure(bands_[i].getType(),
                            sample_rate_,
                            bands_[i].getFrequencyHz(),
                            bands_[i].getQFactor(),
                            bands_[i].getGainDb());
    }
}

bool Equalizer::initStandardBands(uint32_t num_bands) {
    if (num_bands == 5) {
        bands_.clear();
        bands_.resize(5);
        // 5-band configuration
        bands_[0].configure(FilterType::LowShelf,  sample_rate_,    60.0f, 0.7071f, 0.0f);
        bands_[1].configure(FilterType::Peaking,   sample_rate_,   230.0f, 1.4142f, 0.0f);
        bands_[2].configure(FilterType::Peaking,   sample_rate_,   910.0f, 1.4142f, 0.0f);
        bands_[3].configure(FilterType::Peaking,   sample_rate_,  3600.0f, 1.4142f, 0.0f);
        bands_[4].configure(FilterType::HighShelf, sample_rate_, 14000.0f, 0.7071f, 0.0f);
        return true;
    } else if (num_bands == 10) {
        bands_.clear();
        bands_.resize(10);
        // 10-band standard ISO frequencies
        const float freqs[10] = {
            31.25f, 62.5f, 125.0f, 250.0f, 500.0f,
            1000.0f, 2000.0f, 4000.0f, 8000.0f, 16000.0f
        };
        bands_[0].configure(FilterType::LowShelf,  sample_rate_, freqs[0], 0.7071f, 0.0f);
        for (int i = 1; i < 9; ++i) {
            bands_[i].configure(FilterType::Peaking, sample_rate_, freqs[i], 1.4142f, 0.0f);
        }
        bands_[9].configure(FilterType::HighShelf, sample_rate_, freqs[9], 0.7071f, 0.0f);
        return true;
    }
    return false;
}

bool Equalizer::configureBand(uint32_t band_index,
                              FilterType type,
                              float frequency_hz,
                              float q_factor,
                              float gain_db) {
    if (band_index >= bands_.size()) {
        return false;
    }
    bands_[band_index].configure(type, sample_rate_, frequency_hz, q_factor, gain_db);
    return true;
}

bool Equalizer::setBandGain(uint32_t band_index, float gain_db) {
    if (band_index >= bands_.size()) {
        return false;
    }
    bands_[band_index].setGainDb(gain_db);
    return true;
}

float Equalizer::getBandGain(uint32_t band_index) const {
    if (band_index >= bands_.size()) {
        return 0.0f;
    }
    return bands_[band_index].getGainDb();
}

float Equalizer::getBandFrequency(uint32_t band_index) const {
    if (band_index >= bands_.size()) {
        return 0.0f;
    }
    return bands_[band_index].getFrequencyHz();
}

} // namespace dsp
} // namespace sonora
