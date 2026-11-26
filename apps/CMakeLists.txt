add_executable(my_project_app main.cpp)

target_link_libraries(my_project_app
    PRIVATE
        my_project::my_project
)

my_project_set_warnings(my_project_app)
