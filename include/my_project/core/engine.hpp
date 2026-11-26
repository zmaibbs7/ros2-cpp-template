/**
 * @file engine.hpp
 * @brief Core robotics middleware state engine public interface.
 */

#ifndef MY_PROJECT_CORE_ENGINE_HPP
#define MY_PROJECT_CORE_ENGINE_HPP

#include <cstddef>
#include <cstdint>
#include <mutex>

namespace my_project {

/**
 * @brief Core middleware algorithms and runtime state management.
 */
namespace core {

/**
 * @brief Configuration parameters for the core simulation/control engine.
 */
struct EngineConfig {
  /**
   * @brief Fixed integration time step in seconds (must be positive).
   */
  double step_dt_sec = 0.01;

  /**
   * @brief Maximum allowed velocity magnitude in meters per second.
   */
  double max_velocity = 10.0;
};

/**
 * @brief Snapshot of the engine's current kinematic state.
 */
struct EngineState {
  /**
   * @brief Total number of executed update steps.
   */
  std::uint64_t step_count = 0;

  /**
   * @brief Current 1D position in meters.
   */
  double position = 0.0;

  /**
   * @brief Current 1D velocity in meters per second.
   */
  double velocity = 0.0;
};

/**
 * @brief Thread-safe core kinematics engine.
 */
class Engine {
 public:
  /**
   * @brief Construct an engine with the given configuration.
   * @param config Engine configuration parameters.
   */
  explicit Engine(EngineConfig config = EngineConfig{});

  /**
   * @brief Advance the engine state by one time step using the input acceleration.
   * @param acceleration Commanded linear acceleration in m/s^2.
   * @return Updated engine state snapshot.
   */
  EngineState step(double acceleration);

  /**
   * @brief Retrieve a thread-safe snapshot of the current engine state.
   * @return Current engine state.
   */
  EngineState state() const;

  /**
   * @brief Reset position, velocity, and step counter back to zero.
   */
  void reset();

  /**
   * @brief Return the immutable engine configuration.
   * @return Reference to the engine configuration.
   */
  const EngineConfig& config() const noexcept;

 private:
  EngineConfig config_;
  mutable std::mutex mutex_;
  EngineState state_;
};

}  // namespace core
}  // namespace my_project

#endif  // MY_PROJECT_CORE_ENGINE_HPP
