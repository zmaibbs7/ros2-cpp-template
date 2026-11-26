#include "my_project/core/engine.hpp"

#include <algorithm>
#include <stdexcept>

namespace my_project {
namespace core {

Engine::Engine(EngineConfig config) : config_(config) {
  if (config_.step_dt_sec <= 0.0) {
    throw std::invalid_argument("EngineConfig::step_dt_sec must be positive");
  }
  if (config_.max_velocity <= 0.0) {
    throw std::invalid_argument("EngineConfig::max_velocity must be positive");
  }
}

EngineState Engine::step(double acceleration) {
  std::lock_guard<std::mutex> lock(mutex_);
  const double next_velocity = std::clamp(state_.velocity + (acceleration * config_.step_dt_sec),
                                          -config_.max_velocity, config_.max_velocity);
  state_.velocity = next_velocity;
  state_.position += state_.velocity * config_.step_dt_sec;
  ++state_.step_count;
  return state_;
}

EngineState Engine::state() const {
  std::lock_guard<std::mutex> lock(mutex_);
  return state_;
}

void Engine::reset() {
  std::lock_guard<std::mutex> lock(mutex_);
  state_ = EngineState{};
}

const EngineConfig& Engine::config() const noexcept {
  return config_;
}

}  // namespace core
}  // namespace my_project
