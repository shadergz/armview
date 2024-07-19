cmake_minimum_required(VERSION 3.20)
project(armview)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
set(CMAKE_CXX_FLAGS_RELEASE -Ofast)
find_package(LLVM 15.0 REQUIRED
    armdesc armdisassembler aarch64desc aarch64disassembler
)
set(CMAKE_CXX_STANDARD 20)
add_subdirectory(fmt)
add_executable(armview program.cpp)
target_include_directories(armview PRIVATE ${LLVM_INCLUDE_DIRS})
target_link_directories(armview PRIVATE ${LLVM_LIBRARY_DIRS})
target_link_libraries(armview PRIVATE ${LLVM_LIBRARIES} fmt::fmt)
