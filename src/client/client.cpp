#include "my_project/client/client.hpp"

#include <utility>

#include "client/client_impl.hpp"

namespace my_project {
namespace client {

Client::Client(ClientConfig config) : impl_(std::make_unique<Impl>(std::move(config))) {}

Client::~Client() = default;

Client::Client(Client&& other) noexcept = default;
Client& Client::operator=(Client&& other) noexcept = default;

bool Client::connect() {
  return impl_ && impl_->connect();
}

void Client::disconnect() noexcept {
  if (impl_) {
    impl_->disconnect();
  }
}

bool Client::is_connected() const noexcept {
  return impl_ && impl_->is_connected();
}

bool Client::send_command(double acceleration) {
  return impl_ && impl_->send_command(acceleration);
}

double Client::last_position() const noexcept {
  return impl_ ? impl_->last_position() : 0.0;
}

}  // namespace client
}  // namespace my_project
