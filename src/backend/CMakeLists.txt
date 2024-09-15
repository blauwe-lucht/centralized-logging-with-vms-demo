cmake_minimum_required(VERSION 3.10)
project(FibonacciBackend)

# Set C++ version
set(CMAKE_CXX_STANDARD 17)

# Add include directories (Crow and spdlog are header-only)
include_directories(
    /usr/local/include/crow/include
    /usr/local/include/spdlog/include
    /usr/local/include/asio/asio/include
)

# Add the executable
add_executable(fibonacci_backend main.cpp)

target_link_libraries(fibonacci_backend pthread uuid)
