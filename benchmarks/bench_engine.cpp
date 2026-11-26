#include <chrono>
#include <cstdint>
#include <iostream>

#include "my_project/core/engine.hpp"

#ifdef MY_PROJECT_USE_GBENCH
#include <benchmark/benchmark.h>

static void BM_EngineStep(benchmark::State& state) {
  my_project::core::Engine engine;
  for (auto _ : state) {
    auto snapshot = engine.step(1.0);
    benchmark::DoNotOptimize(snapshot);
  }
}
BENCHMARK(BM_EngineStep);

#else

int main() {
  constexpr std::uint64_t kIterations = 1000000;
  my_project::core::Engine engine;

  const auto start = std::chrono::steady_clock::now();
  double accum = 0.0;
  for (std::uint64_t i = 0; i < kIterations; ++i) {
    accum += engine.step(0.5).position;
  }
  const auto end = std::chrono::steady_clock::now();

  const auto elapsed_ns = std::chrono::duration_cast<std::chrono::nanoseconds>(end - start).count();
  const double ns_per_step = static_cast<double>(elapsed_ns) / static_cast<double>(kIterations);

  std::cout << "[Benchmark] Engine::step (" << kIterations << " iterations): " << ns_per_step
            << " ns/step (checksum=" << accum << ")\n";
  return 0;
}

#endif
