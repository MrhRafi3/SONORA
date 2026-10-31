#include "biquad_filter.h"
#include <algorithm>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

namespace sonora {
namespace dsp {

static constexpr uint32_t kBiquadSmoothingFrames = 128; // ~2.6ms transition at 48kHz to eliminate clicks

BiquadFilter::BiquadFilter()
    : type_(FilterType::Peaking),
      sample_rate_(48000.0f),
      frequency_hz_(1000.0f),
      q_factor_(1.4142f),
      target_gain_db_(0.0f),
      current_b0_(1.0f), current_b1_(0.0f), current_b2_(0.0f),
      current_a1_(0.0f), current_a2_(0.0f),
      target_b0_(1.0f), target_b1_(0.0f), target_b2_(0.0f),
      target_a1_(0.0f), target_a2_(0.0f),
      delta_b0_(0.0f), delta_b1_(0.0f), delta_b2_(0.0f),
      delta_a1_(0.0f), delta_a2_(0.0f),
      transition_samples_remaining_(0) {
    reset();
}

void BiquadFilter::reset() {
    s1_[0] = 0.0f; s1_[1] = 0.0f;
    s2_[0] = 0.0f; s2_[1] = 0.0f;
}

void BiquadFilter::configure(FilterType type,
                            float sample_rate,
                            float frequency_hz,
                            float q_factor,
                            float gain_db) {
    type_ = type;
    sample_rate_ = std::max(8000.0f, sample_rate);
    // Clamp center frequency between 10Hz and 0.49 * sample_rate (Nyquist boundary)
    frequency_hz_ = std::max(10.0f, std::min(frequency_hz, sample_rate_ * 0.49f));
    q_factor_ = std::max(0.1f, std::min(q_factor, 20.0f));
    target_gain_db_ = gain_db;

    calculateCoefficients(gain_db, current_b0_, current_b1_, current_b2_, current_a1_, current_a2_);
    target_b0_ = current_b0_;
    target_b1_ = current_b1_;
    target_b2_ = current_b2_;
    target_a1_ = current_a1_;
    target_a2_ = current_a2_;
    transition_samples_remaining_ = 0;
}

void BiquadFilter::setGainDb(float gain_db) {
    if (std::abs(gain_db - target_gain_db_) < 0.01f) {
        return;
    }
    target_gain_db_ = gain_db;
    calculateCoefficients(gain_db, target_b0_, target_b1_, target_b2_, target_a1_, target_a2_);

    transition_samples_remaining_ = kBiquadSmoothingFrames;
    float step = 1.0f / static_cast<float>(kBiquadSmoothingFrames);
    delta_b0_ = (target_b0_ - current_b0_) * step;
    delta_b1_ = (target_b1_ - current_b1_) * step;
    delta_b2_ = (target_b2_ - current_b2_) * step;
    delta_a1_ = (target_a1_ - current_a1_) * step;
    delta_a2_ = (target_a2_ - current_a2_) * step;
}

void BiquadFilter::stepCoefficients() {
    if (transition_samples_remaining_ > 1) {
        current_b0_ += delta_b0_;
        current_b1_ += delta_b1_;
        current_b2_ += delta_b2_;
        current_a1_ += delta_a1_;
        current_a2_ += delta_a2_;
        --transition_samples_remaining_;
    } else {
        current_b0_ = target_b0_;
        current_b1_ = target_b1_;
        current_b2_ = target_b2_;
        current_a1_ = target_a1_;
        current_a2_ = target_a2_;
        transition_samples_remaining_ = 0;
    }
}

void BiquadFilter::calculateCoefficients(float gain_db,
                                       float& b0, float& b1, float& b2,
                                       float& a1, float& a2) {
    float A = std::pow(10.0f, gain_db / 40.0f); // sqrt(10^(gain/20))
    float w0 = 2.0f * static_cast<float>(M_PI) * frequency_hz_ / sample_rate_;
    float cos_w0 = std::cos(w0);
    float sin_w0 = std::sin(w0);
    float alpha = sin_w0 / (2.0f * q_factor_);

    float raw_b0 = 1.0f, raw_b1 = 0.0f, raw_b2 = 0.0f;
    float raw_a0 = 1.0f, raw_a1 = 0.0f, raw_a2 = 0.0f;

    switch (type_) {
        case FilterType::Peaking: {
            raw_b0 = 1.0f + alpha * A;
            raw_b1 = -2.0f * cos_w0;
            raw_b2 = 1.0f - alpha * A;
            raw_a0 = 1.0f + alpha / A;
            raw_a1 = -2.0f * cos_w0;
            raw_a2 = 1.0f - alpha / A;
            break;
        }
        case FilterType::LowShelf: {
            float two_sqrt_A_alpha = 2.0f * std::sqrt(A) * alpha;
            raw_b0 = A * ((A + 1.0f) - (A - 1.0f) * cos_w0 + two_sqrt_A_alpha);
            raw_b1 = 2.0f * A * ((A - 1.0f) - (A + 1.0f) * cos_w0);
            raw_b2 = A * ((A + 1.0f) - (A - 1.0f) * cos_w0 - two_sqrt_A_alpha);
            raw_a0 = (A + 1.0f) + (A - 1.0f) * cos_w0 + two_sqrt_A_alpha;
            raw_a1 = -2.0f * ((A - 1.0f) + (A + 1.0f) * cos_w0);
            raw_a2 = (A + 1.0f) + (A - 1.0f) * cos_w0 - two_sqrt_A_alpha;
            break;
        }
        case FilterType::HighShelf: {
            float two_sqrt_A_alpha = 2.0f * std::sqrt(A) * alpha;
            raw_b0 = A * ((A + 1.0f) + (A - 1.0f) * cos_w0 + two_sqrt_A_alpha);
            raw_b1 = -2.0f * A * ((A - 1.0f) + (A + 1.0f) * cos_w0);
            raw_b2 = A * ((A + 1.0f) + (A - 1.0f) * cos_w0 - two_sqrt_A_alpha);
            raw_a0 = (A + 1.0f) - (A - 1.0f) * cos_w0 + two_sqrt_A_alpha;
            raw_a1 = 2.0f * ((A - 1.0f) - (A + 1.0f) * cos_w0);
            raw_a2 = (A + 1.0f) - (A - 1.0f) * cos_w0 - two_sqrt_A_alpha;
            break;
        }
        case FilterType::LowPass: {
            raw_b0 = (1.0f - cos_w0) * 0.5f;
            raw_b1 = 1.0f - cos_w0;
            raw_b2 = (1.0f - cos_w0) * 0.5f;
            raw_a0 = 1.0f + alpha;
            raw_a1 = -2.0f * cos_w0;
            raw_a2 = 1.0f - alpha;
            break;
        }
        case FilterType::HighPass: {
            raw_b0 = (1.0f + cos_w0) * 0.5f;
            raw_b1 = -(1.0f + cos_w0);
            raw_b2 = (1.0f + cos_w0) * 0.5f;
            raw_a0 = 1.0f + alpha;
            raw_a1 = -2.0f * cos_w0;
            raw_a2 = 1.0f - alpha;
            break;
        }
        case FilterType::BandPass: {
            raw_b0 = alpha;
            raw_b1 = 0.0f;
            raw_b2 = -alpha;
            raw_a0 = 1.0f + alpha;
            raw_a1 = -2.0f * cos_w0;
            raw_a2 = 1.0f - alpha;
            break;
        }
        case FilterType::Notch: {
            raw_b0 = 1.0f;
            raw_b1 = -2.0f * cos_w0;
            raw_b2 = 1.0f;
            raw_a0 = 1.0f + alpha;
            raw_a1 = -2.0f * cos_w0;
            raw_a2 = 1.0f - alpha;
            break;
        }
    }

    // Normalize coefficients so that a0 = 1.0
    float inv_a0 = 1.0f / raw_a0;
    b0 = raw_b0 * inv_a0;
    b1 = raw_b1 * inv_a0;
    b2 = raw_b2 * inv_a0;
    a1 = raw_a1 * inv_a0;
    a2 = raw_a2 * inv_a0;
}

} // namespace dsp
} // namespace sonora
