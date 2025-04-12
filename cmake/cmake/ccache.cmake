# Use ccache for faster rebuilds
find_program(CCACHE ccache)
if (CCACHE)
  message(STATUS "Using ccache")
  set(CMAKE_CXX_COMPILER_LAUNCHER ${CCACHE})
else ()
  message(STATUS "Ccache not found")
endif ()