cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES CXX)

set(BINARY_NAME "prompt_gladiators")
set(APPLICATION_ID "com.promptgladiators.app")

cmake_policy(SET CMP0063 NEW)

set(CMAKE_INSTALL_PREFIX "${CMAKE_BINARY_DIR}/install")

# Flutter library and tool build rules
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../flutter")

# System-level dependencies
find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK REQUIRED IMPORTED_TARGET gtk+-3.0)

add_subdirectory(${FLUTTER_MANAGED_DIR})

# Application build
add_subdirectory("runner")

# Generated plugin build rules
include(flutter/generated_plugins.cmake OPTIONAL)

# Standard install
install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION bin)
install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION bin)
install(FILES "${FLUTTER_LIBRARY}" DESTINATION lib)
