#include "preamp.h"

namespace sonora {
namespace dsp {

static constexpr uint32_t kPreampSmoothingFrames = 128;

Preamp::Preamp()
    : target_gain_db_(0.0f),
      current_linear_gain_(1.0f),
      target_linear_gain_(1.0f),
      delta_linear_gain_(0.0f),
      transition_samples_remaining_(0),
      limiter_enabled_(true) {
}

void Preamp::reset() {
    current_linear_gain_ = target_linear_gain_;
    transition_samples_remaining_ = 0;
    delta_linear_gain_ = 0.0f;
}

void Preamp::setGainDb(float gain_db) {
    target_gain_db_ = std::max(-24.0f, std::min(gain_db, 24.0f));
    target_linear_gain_ = std::pow(10.0f, target_gain_db_ / 20.0f);

    transition_samples_remaining_ = kPreampSmoothingFrames;
    delta_linear_gain_ = (target_linear_gain_ - current_linear_gain_) / static_cast<float>(kPreampSmoothingFrames);
}

} // namespace dsp
} // namespace sonora
