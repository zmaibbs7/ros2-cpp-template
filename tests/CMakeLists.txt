# 优先查找本地预编译 GTest；未找到则探测常见本地源码路径；均缺失时使用零依赖标准 C++ 测试桩保底
my_project_find_or_build_package(GTest
    RESULT_VAR MY_PROJECT_HAS_GTEST
    SUBDIR_BINARY_NAME googletest
    SOURCE_HINTS
        "${PROJECT_SOURCE_DIR}/third_party/googletest"
        "/usr/src/googletest"
)

add_executable(test_core test_core.cpp)
target_link_libraries(test_core
    PRIVATE
        my_project::my_project
)
my_project_set_warnings(test_core)

if(MY_PROJECT_HAS_GTEST)
    target_compile_definitions(test_core PRIVATE MY_PROJECT_USE_GTEST=1)
    if(TARGET GTest::gtest_main)
        target_link_libraries(test_core PRIVATE GTest::gtest_main)
    elseif(TARGET gtest_main)
        target_link_libraries(test_core PRIVATE gtest_main)
    endif()
    include(GoogleTest)
    gtest_discover_tests(test_core)
else()
    message(STATUS "[my_project] GTest not found; using zero-dependency C++ test runner fallback.")
    add_test(NAME test_core COMMAND test_core)
endif()
