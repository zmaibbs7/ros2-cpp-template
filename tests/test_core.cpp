#include <cmath>
#include <iostream>
#include <stdexcept>
#include <thread>
#include <utility>
#include <vector>

#include "my_project/client/client.hpp"
#include "my_project/core/engine.hpp"
#include "my_project/version.hpp"

#ifdef MY_PROJECT_USE_GTEST
#include <gtest/gtest.h>
#endif

namespace {

bool nearly_equal(double lhs, double rhs, double eps = 1e-9) {
  return std::fabs(lhs - rhs) <= eps;
}

bool check_version_metadata() {
  return my_project::version_major() == 0 && my_project::version_minor() == 1 &&
         my_project::version_patch() == 0 && !my_project::version_string().empty() &&
         !my_project::git_commit_hash().empty();
}

bool check_engine_kinematics() {
  my_project::core::EngineConfig cfg;
  cfg.step_dt_sec = 0.1;
  cfg.max_velocity = 1.0;

  my_project::core::Engine engine(cfg);
  const auto s1 = engine.step(2.0);
  if (s1.step_count != 1 || !nearly_equal(s1.velocity, 0.2) || !nearly_equal(s1.position, 0.02)) {
    return false;
  }

  // Clamp velocity at max_velocity
  for (int i = 0; i < 20; ++i) {
    engine.step(5.0);
  }
  const auto s_clamped = engine.state();
  if (!nearly_equal(s_clamped.velocity, 1.0)) {
    return false;
  }

  engine.reset();
  const auto s_reset = engine.state();
  return s_reset.step_count == 0 && nearly_equal(s_reset.position, 0.0) &&
         nearly_equal(s_reset.velocity, 0.0);
}

bool check_engine_invalid_config() {
  bool caught_dt = false;
  try {
    my_project::core::EngineConfig bad_cfg;
    bad_cfg.step_dt_sec = 0.0;
    my_project::core::Engine engine(bad_cfg);
    (void)engine;
  } catch (const std::invalid_argument&) {
    caught_dt = true;
  }
  return caught_dt;
}

bool check_client_pimpl_lifecycle() {
  my_project::client::Client client;
  if (client.is_connected() || client.send_command(1.0)) {
    return false;
  }
  if (!client.connect() || !client.is_connected()) {
    return false;
  }
  if (!client.send_command(10.0) || client.last_position() <= 0.0) {
    return false;
  }

  my_project::client::Client moved_client = std::move(client);
  if (!moved_client.is_connected()) {
    return false;
  }
  moved_client.disconnect();
  return !moved_client.is_connected();
}

bool check_engine_thread_safety() {
  my_project::core::Engine engine;
  constexpr int kThreads = 4;
  constexpr int kStepsPerThread = 250;

  std::vector<std::thread> workers;
  workers.reserve(kThreads);
  for (int t = 0; t < kThreads; ++t) {
    workers.emplace_back([&engine]() {
      for (int i = 0; i < kStepsPerThread; ++i) {
        engine.step(0.5);
        (void)engine.state();
      }
    });
  }
  for (auto& worker : workers) {
    worker.join();
  }

  return engine.state().step_count == static_cast<std::uint64_t>(kThreads * kStepsPerThread);
}

}  // namespace

#ifdef MY_PROJECT_USE_GTEST

TEST(VersionTest, MetadataIsValid) {
  EXPECT_TRUE(check_version_metadata());
}

TEST(EngineTest, KinematicsAndReset) {
  EXPECT_TRUE(check_engine_kinematics());
}

TEST(EngineTest, InvalidConfigThrows) {
  EXPECT_TRUE(check_engine_invalid_config());
}

TEST(ClientTest, PImplLifecycleAndMove) {
  EXPECT_TRUE(check_client_pimpl_lifecycle());
}

TEST(EngineTest, ConcurrentSteppingIsThreadSafe) {
  EXPECT_TRUE(check_engine_thread_safety());
}

#else

int main() {
  struct TestCase {
    const char* name;
    bool (*fn)();
  };

  const TestCase cases[] = {
      {"VersionMetadata", check_version_metadata},
      {"EngineKinematics", check_engine_kinematics},
      {"EngineInvalidConfig", check_engine_invalid_config},
      {"ClientPImplLifecycle", check_client_pimpl_lifecycle},
      {"EngineThreadSafety", check_engine_thread_safety},
  };

  int failures = 0;
  for (const auto& tc : cases) {
    if (tc.fn()) {
      std::cout << "[  PASS  ] " << tc.name << "\n";
    } else {
      std::cerr << "[  FAIL  ] " << tc.name << "\n";
      ++failures;
    }
  }
  return failures == 0 ? 0 : 1;
}

#endif
