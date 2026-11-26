# 优先查找本地预编译 Google Benchmark；未找到则回退本地源码；均缺失时使用 std::chrono 压测桩
my_project_find_or_build_package(benchmark
    RESULT_VAR MY_PROJECT_HAS_GBENCH
    SUBDIR_BINARY_NAME benchmark
    SOURCE_HINTS
        "${PROJECT_SOURCE_DIR}/third_party/benchmark"
)

add_executable(bench_engine bench_engine.cpp)
target_link_libraries(bench_engine
    PRIVATE
        my_project::my_project
)
my_project_set_warnings(bench_engine)

if(MY_PROJECT_HAS_GBENCH AND TARGET benchmark::benchmark_main)
    target_compile_definitions(bench_engine PRIVATE MY_PROJECT_USE_GBENCH=1)
    target_link_libraries(bench_engine PRIVATE benchmark::benchmark_main)
else()
    message(STATUS "[my_project] Google Benchmark not found; using std::chrono benchmark fallback.")
endif()
