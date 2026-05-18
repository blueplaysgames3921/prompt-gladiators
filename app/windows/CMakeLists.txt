cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

set(BINARY_NAME "prompt_gladiators")
set(APPLICATION_ID "com.promptgladiators.app")

cmake_policy(SET CMP0063 NEW)

set(CMAKE_INSTALL_PREFIX "${CMAKE_BINARY_DIR}/install")
set(BUILD_BUNDLE_DIR "${PROJECT_BINARY_DIR}/win32")

# Flutter library and tool build rules
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../flutter")
include(flutter/generated_plugins.cmake OPTIONAL)

# Application build
add_subdirectory("runner")

# Generated plugin build rules (from flutter pub get)
include(flutter/generated_plugins.cmake OPTIONAL)

# Windows installer (optional)
if(MSIX_PATH)
  include(flutter/generated_plugins.cmake OPTIONAL)
endif()

# Standard install steps
install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}")
