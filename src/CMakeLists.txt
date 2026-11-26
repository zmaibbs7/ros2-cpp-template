find_package(Threads REQUIRED)

# 配置期捕获当前 Git Commit Hash，注入到内部 version.cpp 而非公共头文件（避免全量重编雪崩）
set(MY_PROJECT_GIT_COMMIT_HASH "unknown")
find_package(Git QUIET)
if(GIT_FOUND)
    execute_process(
        COMMAND "${GIT_EXECUTABLE}" rev-parse --short HEAD
        WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
        OUTPUT_VARIABLE _git_hash
        ERROR_QUIET
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    if(_git_hash)
        set(MY_PROJECT_GIT_COMMIT_HASH "${_git_hash}")
    endif()
endif()

configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/core/version.cpp.in"
    "${CMAKE_CURRENT_BINARY_DIR}/version.cpp"
    @ONLY
)

add_library(my_project
    "${CMAKE_CURRENT_BINARY_DIR}/version.cpp"
    core/engine.cpp
    client/client.cpp
)
add_library(my_project::my_project ALIAS my_project)

target_compile_features(my_project PUBLIC cxx_std_${MY_PROJECT_CXX_STANDARD})

target_include_directories(my_project
    PUBLIC
        $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(my_project
    PUBLIC
        Threads::Threads
)

my_project_set_warnings(my_project)
my_project_enable_sanitizers(my_project)
