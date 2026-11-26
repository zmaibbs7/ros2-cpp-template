/**
 * @file client.hpp
 * @brief Public SDK client interface using the PImpl idiom to hide internal dependencies.
 */

#ifndef MY_PROJECT_CLIENT_CLIENT_HPP
#define MY_PROJECT_CLIENT_CLIENT_HPP

#include <memory>
#include <string>

namespace my_project {

/**
 * @brief External SDK client interfaces.
 */
namespace client {

/**
 * @brief Configuration for creating a middleware SDK client.
 */
struct ClientConfig {
  /**
   * @brief Target middleware endpoint URI (e.g. "local://engine").
   */
  std::string endpoint = "local://engine";

  /**
   * @brief Command timeout in milliseconds.
   */
  int timeout_ms = 1000;
};

/**
 * @brief High-level SDK client with binary-compatible PImpl encapsulation.
 */
class Client {
 public:
  /**
   * @brief Construct a client instance with the specified configuration.
   * @param config Client connection configuration.
   */
  explicit Client(ClientConfig config = ClientConfig{});

  /**
   * @brief Destroy the client and release internal resources.
   */
  ~Client();

  Client(const Client&) = delete;
  Client& operator=(const Client&) = delete;

  /**
   * @brief Move-construct a client instance.
   * @param other Source client to move from.
   */
  Client(Client&& other) noexcept;

  /**
   * @brief Move-assign a client instance.
   * @param other Source client to move from.
   * @return Reference to this client.
   */
  Client& operator=(Client&& other) noexcept;

  /**
   * @brief Establish a session with the configured endpoint.
   * @return True if connected successfully, false otherwise.
   */
  bool connect();

  /**
   * @brief Close the active client session.
   */
  void disconnect() noexcept;

  /**
   * @brief Check whether the client currently has an active session.
   * @return True if connected, false otherwise.
   */
  bool is_connected() const noexcept;

  /**
   * @brief Send an acceleration command to the backend engine.
   * @param acceleration Commanded acceleration in m/s^2.
   * @return True if the command was accepted, false if disconnected.
   */
  bool send_command(double acceleration);

  /**
   * @brief Query the most recently observed position from the backend.
   * @return Last observed position in meters.
   */
  double last_position() const noexcept;

 private:
  class Impl;
  std::unique_ptr<Impl> impl_;
};

}  // namespace client
}  // namespace my_project

#endif  // MY_PROJECT_CLIENT_CLIENT_HPP
