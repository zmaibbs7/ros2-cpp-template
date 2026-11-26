include_guard(GLOBAL)

function(my_project_set_warnings target_name)
    set(COMMON_WARNINGS
        -Wall
        -Wextra
        -Wpedantic
        -Wshadow
        -Wnon-virtual-dtor
        -Wold-style-cast
        -Wcast-align
        -Wunused
        -Woverloaded-virtual
        -Wconversion
        -Wsign-conversion
        -Wnull-dereference
        -Wdouble-promotion
        -Wformat=2
    )

    set(GCC_EXTRA_WARNINGS
        -Wmisleading-indentation
        -Wduplicated-cond
        -Wduplicated-branches
        -Wlogical-op
        -Wuseless-cast
    )

    set(PROJECT_WARNINGS "")
    if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
        set(PROJECT_WARNINGS ${COMMON_WARNINGS})
    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
        set(PROJECT_WARNINGS ${COMMON_WARNINGS} ${GCC_EXTRA_WARNINGS})
    else()
        message(AUTHOR_WARNING "No compiler warning flags configured for '${CMAKE_CXX_COMPILER_ID}'.")
    endif()

    if(MY_PROJECT_WARNINGS_AS_ERRORS)
        list(APPEND PROJECT_WARNINGS -Werror)
    endif()

    target_compile_options(${target_name} PRIVATE ${PROJECT_WARNINGS})
endfunction()
