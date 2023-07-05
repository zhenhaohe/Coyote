cmake_minimum_required(VERSION 3.0)
project(ip_project)

if (NOT hasParent)
    set(FDEV_NAME "u55c")
endif()

if(FDEV_NAME STREQUAL "u250")
    set(DEVICE "xcu250-figd2104-2L-e")
elseif(FDEV_NAME STREQUAL "u280")
    set(DEVICE "xcu280-fsvh2892-2L-e")
elseif(FDEV_NAME STREQUAL "u55c")
    set(DEVICE "xcu55c-fsvh2892-2L-e")
endif()

#Setup HLS custom targets
set(HLS_TARGETS csim syn cosim ip services)

set(HLS "vitis_hls")

function(add_custom_target_with_dependency TARGET_NAME DEPENDENCY_NAME)
    if (NOT TARGET ${TARGET_NAME})
        add_custom_target(${TARGET_NAME})
    endif()

    add_custom_target(${TARGET_NAME}.${DEPENDENCY_NAME}
        COMMAND ${HLS} ${CMAKE_CURRENT_LIST_DIR}/make.tcl -tclargs ${TARGET_NAME} ${DEPENDENCY_NAME} ${DEVICE} ${IPREPO_DIR} ${CMAKE_CURRENT_BINARY_DIR}
        DEPENDS ${CMAKE_CURRENT_LIST_DIR}/make.tcl ${DEPENDENCY_NAME}.cpp 
        COMMENT "Building ${DEPENDENCY_NAME}")
    add_dependencies(${TARGET_NAME} ${TARGET_NAME}.${DEPENDENCY_NAME})
endfunction()

foreach (target ${HLS_TARGETS})
    add_custom_target_with_dependency(${target} hmac_eLen_handler)
    add_custom_target_with_dependency(${target} auth_key_handler)
    add_custom_target_with_dependency(${target} auth_pipe_out_handler)
endforeach()

# Installation
if (DEFINED ENV{IPREPO_DIR})
   set(IPREPO_DIR $ENV{IPREPO_DIR})
elseif(NOT  IPREPO_DIR)
   set(IPREPO_DIR ${CMAKE_CURRENT_SOURCE_DIR}/iprepo/)
endif()

