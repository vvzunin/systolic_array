cmake_minimum_required(VERSION 3.30)

project(systolicarray-gui)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(IMGUI_DIR ${CMAKE_CURRENT_SOURCE_DIR}/lib/imgui)

include(cmake/ccache.cmake)

add_subdirectory(src)