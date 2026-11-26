cmake_minimum_required(VERSION 3.16)

# ------------------------------------------------------------------------------
# 防源码内构建保护：避免误执行 `cmake .` 污染源码树及覆盖根目录 Makefile
# ------------------------------------------------------------------------------
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_BINARY_DIR)
    message(FATAL_ERROR
        "In-source builds are not allowed. Please use an out-of-source build directory, e.g.:\n"
        "  make build\n"
        "or:\n"
        "  cmake -S . -B build/debug -DCMAKE_BUILD_TYPE=Debug")
endif()

project(my_project
    VERSION 0.1.0
    DESCRIPTION "Modern C++ ROS 2 middleware core library template"
    LANGUAGES CXX
)

# ------------------------------------------------------------------------------
# 兼容 CMake 3.16+ 的顶层工程守卫（避免强依赖 CMake 3.21 的 PROJECT_IS_TOP_LEVEL）
# 当本仓库被其他工程通过 add_subdirectory 引入时，自动关闭测试/示例/文档/-Werror
# ------------------------------------------------------------------------------
string(COMPARE EQUAL "${CMAKE_SOURCE_DIR}" "${CMAKE_CURRENT_SOURCE_DIR}" MY_PROJECT_IS_TOP_LEVEL)

# ------------------------------------------------------------------------------
# C++ 标准配置（默认 C++17 契合 ROS 2 主力生态，一键切换 C++20）
# ------------------------------------------------------------------------------
set(MY_PROJECT_CXX_STANDARD "17" CACHE STRING "C++ standard version (17 or 20)")
set_property(CACHE MY_PROJECT_CXX_STANDARD PROPERTY STRINGS "17" "20")
if(NOT MY_PROJECT_CXX_STANDARD STREQUAL "17" AND NOT MY_PROJECT_CXX_STANDARD STREQUAL "20")
    message(FATAL_ERROR "Unsupported MY_PROJECT_CXX_STANDARD='${MY_PROJECT_CXX_STANDARD}'. Supported values: 17, 20.")
endif()

set(CMAKE_CXX_STANDARD ${MY_PROJECT_CXX_STANDARD})
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# 默认导出 compile_commands.json 供 clangd 与 clang-tidy 使用
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# ------------------------------------------------------------------------------
# 构建开关
# ------------------------------------------------------------------------------
option(BUILD_SHARED_LIBS "Build shared libraries instead of static libraries" OFF)
option(MY_PROJECT_BUILD_APPS "Build executable applications" ${MY_PROJECT_IS_TOP_LEVEL})
option(MY_PROJECT_BUILD_TESTS "Build unit and integration tests" ${MY_PROJECT_IS_TOP_LEVEL})
option(MY_PROJECT_BUILD_EXAMPLES "Build SDK/client usage examples" ${MY_PROJECT_IS_TOP_LEVEL})
option(MY_PROJECT_ENABLE_BENCHMARKS "Build performance benchmarks" OFF)
option(MY_PROJECT_BUILD_DOCS "Register Doxygen documentation and comment-check targets" ${MY_PROJECT_IS_TOP_LEVEL})
option(MY_PROJECT_WARNINGS_AS_ERRORS "Treat compiler warnings as errors" ${MY_PROJECT_IS_TOP_LEVEL})
option(MY_PROJECT_ENABLE_IPO "Enable Interprocedural Optimization (LTO) when supported" OFF)

# ------------------------------------------------------------------------------
# 标准模块与原生辅助脚本
# ------------------------------------------------------------------------------
include(GNUInstallDirs)
include(CMakePackageConfigHelpers)
include(CheckIPOSupported)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(CompilerWarnings)
include(Sanitizers)
include(Dependencies)

if(MY_PROJECT_ENABLE_IPO)
    check_ipo_supported(RESULT ipo_supported OUTPUT ipo_error)
    if(ipo_supported)
        set(CMAKE_INTERPROCEDURAL_OPTIMIZATION ON)
        message(STATUS "[my_project] IPO/LTO enabled.")
    else()
        message(WARNING "[my_project] IPO/LTO requested but not supported: ${ipo_error}")
    endif()
endif()

# ------------------------------------------------------------------------------
# 核心库（Library-First 分层）
# ------------------------------------------------------------------------------
add_subdirectory(src)

# ------------------------------------------------------------------------------
# 可选子模块（应用 / 测试 / 压测 / 示例 / 文档）
# ------------------------------------------------------------------------------
if(MY_PROJECT_BUILD_APPS)
    add_subdirectory(apps)
endif()

if(MY_PROJECT_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()

if(MY_PROJECT_ENABLE_BENCHMARKS)
    add_subdirectory(benchmarks)
endif()

if(MY_PROJECT_BUILD_EXAMPLES)
    add_subdirectory(examples)
endif()

if(MY_PROJECT_BUILD_DOCS)
    add_subdirectory(docs)
endif()

# ------------------------------------------------------------------------------
# 标准安装规则与 find_package 导出（兼容独立安装与 ROS 2 colcon build）
# ------------------------------------------------------------------------------
if(MY_PROJECT_IS_TOP_LEVEL)
    install(TARGETS my_project
        EXPORT my_projectTargets
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    )

    install(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/include/my_project"
        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
    )

    install(EXPORT my_projectTargets
        FILE my_projectTargets.cmake
        NAMESPACE my_project::
        DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/my_project
    )

    configure_package_config_file(
        "${CMAKE_CURRENT_SOURCE_DIR}/cmake/my_projectConfig.cmake.in"
        "${CMAKE_CURRENT_BINARY_DIR}/my_projectConfig.cmake"
        INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/my_project
    )

    write_basic_package_version_file(
        "${CMAKE_CURRENT_BINARY_DIR}/my_projectConfigVersion.cmake"
        VERSION ${PROJECT_VERSION}
        COMPATIBILITY SameMajorVersion
    )

    install(FILES
        "${CMAKE_CURRENT_BINARY_DIR}/my_projectConfig.cmake"
        "${CMAKE_CURRENT_BINARY_DIR}/my_projectConfigVersion.cmake"
        DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/my_project
    )
endif()
