#include <iostream>

#include "my_project/client/client.hpp"

int main() {
  my_project::client::ClientConfig cfg;
  cfg.endpoint = "local://robot_middleware";
  cfg.timeout_ms = 500;

  my_project::client::Client client(cfg);
  if (!client.connect()) {
    std::cerr << "Unable to connect to endpoint: " << cfg.endpoint << "\n";
    return 1;
  }

  for (int step = 0; step < 5; ++step) {
    client.send_command(2.0);
    std::cout << "Step " << step << " -> position: " << client.last_position() << " m\n";
  }

  client.disconnect();
  return 0;
}
