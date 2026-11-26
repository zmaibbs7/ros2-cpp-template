find_package(Doxygen QUIET)

if(NOT DOXYGEN_FOUND)
    message(STATUS "[my_project] Doxygen not found; 'docs' and 'check-docs' targets are skipped.")
    return()
endif()

# 1. check-docs: 毫秒级严格校验 include/ 公共头文件注释（不生成 HTML）
set(DOXYGEN_GENERATE_HTML "NO")
set(DOXYGEN_OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/check")
configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/Doxyfile.in"
    "${CMAKE_CURRENT_BINARY_DIR}/Doxyfile.check"
    @ONLY
)

add_custom_target(check-docs
    COMMAND "${DOXYGEN_EXECUTABLE}" "${CMAKE_CURRENT_BINARY_DIR}/Doxyfile.check"
    WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
    COMMENT "Checking Doxygen comments for public headers in include/"
    VERBATIM
)

# 2. docs: 生成本地离线 HTML API 文档
set(DOXYGEN_GENERATE_HTML "YES")
set(DOXYGEN_OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/html")
configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/Doxyfile.in"
    "${CMAKE_CURRENT_BINARY_DIR}/Doxyfile.html"
    @ONLY
)

add_custom_target(docs
    COMMAND "${DOXYGEN_EXECUTABLE}" "${CMAKE_CURRENT_BINARY_DIR}/Doxyfile.html"
    WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
    COMMENT "Generating local HTML API documentation in ${DOXYGEN_OUTPUT_DIR}"
    VERBATIM
)
