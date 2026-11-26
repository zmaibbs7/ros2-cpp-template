include_guard(GLOBAL)

# ==============================================================================
# 本地依赖探测标准模块（100% 离线自治，不联网拉取）
# 策略：
#   1. 优先通过 find_package 查找本地已安装的预编译动态库/静态库
#      （系统路径、ROS 2 环境、Conda 或 CMAKE_PREFIX_PATH 指定路径）
#   2. 若本地未找到预编译包，则按候选路径回退查找本地源码目录，
#      命中后通过 add_subdirectory(... EXCLUDE_FROM_ALL) 编译
# ==============================================================================

function(my_project_find_or_build_package pkg_name)
    cmake_parse_arguments(ARG "" "RESULT_VAR;SUBDIR_BINARY_NAME" "SOURCE_HINTS;FIND_ARGS" ${ARGN})

    if(NOT ARG_RESULT_VAR)
        string(TOUPPER "${pkg_name}" pkg_upper)
        set(ARG_RESULT_VAR "MY_PROJECT_HAS_${pkg_upper}")
    endif()

    if(NOT ARG_SUBDIR_BINARY_NAME)
        string(TOLOWER "${pkg_name}" ARG_SUBDIR_BINARY_NAME)
    endif()

    # Stage 1: 优先查找本地已编译好的动态库/静态库
    find_package(${pkg_name} QUIET ${ARG_FIND_ARGS})
    if(${pkg_name}_FOUND)
        message(STATUS "[my_project] Dependency '${pkg_name}': using local prebuilt package.")
        set(${ARG_RESULT_VAR} TRUE PARENT_SCOPE)
        return()
    endif()

    # Stage 2: 未找到预编译包时，探测本地受控源码目录进行编译
    string(TOUPPER "${pkg_name}" pkg_upper)
    set(USER_SOURCE_DIR "${MY_PROJECT_${pkg_upper}_SOURCE_DIR}")
    set(ALL_HINTS ${USER_SOURCE_DIR} ${ARG_SOURCE_HINTS})

    foreach(hint_dir IN LISTS ALL_HINTS)
        if(hint_dir AND EXISTS "${hint_dir}/CMakeLists.txt")
            message(STATUS "[my_project] Dependency '${pkg_name}': prebuilt package not found, building from local source '${hint_dir}'.")
            add_subdirectory("${hint_dir}" "${CMAKE_BINARY_DIR}/_deps/${ARG_SUBDIR_BINARY_NAME}" EXCLUDE_FROM_ALL)
            set(${ARG_RESULT_VAR} TRUE PARENT_SCOPE)
            return()
        endif()
    endforeach()

    message(STATUS "[my_project] Dependency '${pkg_name}': neither local prebuilt package nor local source found.")
    set(${ARG_RESULT_VAR} FALSE PARENT_SCOPE)
endfunction()
