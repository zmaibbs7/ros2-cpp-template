#include <iostream>

#include "my_project/client/client.hpp"
#include "my_project/version.hpp"

int main() {
  std::cout << "my_project v" << my_project::version_string()
            << " (git: " << my_project::git_commit_hash() << ")\n";

  my_project::client::Client client;
  if (!client.connect()) {
    std::cerr << "Failed to connect client\n";
    return 1;
  }

  for (int i = 0; i < 10; ++i) {
    client.send_command(1.5);
  }

  std::cout << "Final position: " << client.last_position() << " m\n";
  client.disconnect();
  return 0;
}
