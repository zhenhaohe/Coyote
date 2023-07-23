cmake_minimum_required(VERSION 3.0)
project(bft)

# Includes
include_directories(${CMAKE_SOURCE_DIR}/../include ${CMAKE_SOURCE_DIR}/../../../include)

# Sources
file(GLOB SOURCES ${CMAKE_SOURCE_DIR}/*.cpp ${CMAKE_SOURCE_DIR}/../src/*.cpp ${CMAKE_SOURCE_DIR}/../../../src/*.cpp)

# AVX support (Disable on Enzian)
set(EN_AVX 1 CACHE STRING "AVX environment.")

# Exec
set(EXEC main)

# Compilation
set (CMAKE_CXX_STANDARD 17)
if(EN_AVX)
    set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -pthread -mavx -march=native -O3")
else()
    set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -pthread -march=native -O1")
endif()

# Boost lib
find_package(Boost COMPONENTS program_options REQUIRED)

# MPI
find_package(MPI REQUIRED)
message(STATUS "MPI Include Path: ${MPI_CXX_INCLUDE_PATH}")


# Targets
add_executable(${EXEC} ${SOURCES})
target_link_libraries(${EXEC} ${Boost_LIBRARIES} MPI::MPI_CXX)
target_include_directories(${EXEC} PUBLIC ${MPI_CXX_INCLUDE_PATH})

