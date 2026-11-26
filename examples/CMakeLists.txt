add_executable(basic_client basic_client.cpp)

target_link_libraries(basic_client
    PRIVATE
        my_project::my_project
)

my_project_set_warnings(basic_client)
