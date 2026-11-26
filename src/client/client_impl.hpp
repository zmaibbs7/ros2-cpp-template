#ifndef MY_PROJECT_SRC_CLIENT_CLIENT_IMPL_HPP
#define MY_PROJECT_SRC_CLIENT_CLIENT_IMPL_HPP

#include <atomic>

#include "my_project/client/client.hpp"
#include "my_project/core/engine.hpp"

namespace my_project {
namespace client {

class Client::Impl {
 public:
  explicit Impl(ClientConfig config) : config_(std::move(config)) {}

  bool connect() {
    if (config_.endpoint.empty() || config_.timeout_ms <= 0) {
      return false;
    }
    connected_.store(true, std::memory_order_release);
    return true;
  }

  void disconnect() noexcept {
    connected_.store(false, std::memory_order_release);
  }

  bool is_connected() const noexcept {
    return connected_.load(std::memory_order_acquire);
  }

  bool send_command(double acceleration) {
    if (!is_connected()) {
      return false;
    }
    const auto snapshot = engine_.step(acceleration);
    last_position_.store(snapshot.position, std::memory_order_release);
    return true;
  }

  double last_position() const noexcept {
    return last_position_.load(std::memory_order_acquire);
  }

 private:
  ClientConfig config_;
  std::atomic<bool> connected_{false};
  std::atomic<double> last_position_{0.0};
  core::Engine engine_;
};

}  // namespace client
}  // namespace my_project

#endif  // MY_PROJECT_SRC_CLIENT_CLIENT_IMPL_HPP
