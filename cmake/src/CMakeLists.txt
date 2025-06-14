set(NAME systolicarray-gui-main)

file(GLOB_RECURSE source_files
    "*.cpp")

add_executable(${NAME} 
    ${source_files} 
    ${IMGUI_DIR}/backends/imgui_impl_sdlrenderer2.cpp 
    ${IMGUI_DIR}/backends/imgui_impl_sdl2.cpp
    ${IMGUI_DIR}/imgui.cpp 
    ${IMGUI_DIR}/imgui_draw.cpp 
    ${IMGUI_DIR}/imgui_demo.cpp
    ${IMGUI_DIR}/imgui_tables.cpp 
    ${IMGUI_DIR}/misc/cpp/imgui_stdlib.cpp 
    ${IMGUI_DIR}/imgui_widgets.cpp)

find_package(SDL2 REQUIRED)
include_directories(${SDL2_INCLUDE_DIRS})

find_package(SDL2_image REQUIRED)
include_directories(${SDL2_IMAGE_INCLUDE_DIRS} ${IMGUI_DIR} ${IMGUI_DIR}/backends ${IMGUI_DIR}/misc/cpp)

cmake_policy(SET CMP0167 NEW)
find_package(Boost REQUIRED COMPONENTS system )

target_include_directories(${NAME} PRIVATE "${CMAKE_SOURCE_DIR}/include")

target_link_libraries(${NAME} PRIVATE
    ${SDL2_LIBRARIES}
    SDL2_image::SDL2_image
    Boost::system
    )

target_compile_definitions(${NAME} PRIVATE DEFAULT_FILENAME_FONT="${CMAKE_SOURCE_DIR}/res/CaskaydiaMonoNerdFontMono-Regular.ttf")
target_compile_definitions(${NAME} PRIVATE DEFAULT_FILENAME_WEIGHTS="${CMAKE_SOURCE_DIR}/weights.csv")
target_compile_definitions(${NAME} PRIVATE DEFAULT_FILENAME_DATA="${CMAKE_SOURCE_DIR}/data.csv")
target_compile_definitions(${NAME} PRIVATE DEFAULT_FILENAME_RES="${CMAKE_SOURCE_DIR}/result.csv")
