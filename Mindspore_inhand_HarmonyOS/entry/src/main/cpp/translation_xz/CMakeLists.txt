cmake_minimum_required(VERSION 3.20)
project(translation_archive LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(XZ_IMPORTED_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/third_party/xz" CACHE PATH "Pinned XZ import root")
add_library(liblzma STATIC IMPORTED GLOBAL)
set_target_properties(liblzma PROPERTIES
  IMPORTED_LOCATION "${XZ_IMPORTED_ROOT}/lib/${OHOS_ARCH}/liblzma.a"
  INTERFACE_INCLUDE_DIRECTORIES "${XZ_IMPORTED_ROOT}/include"
)

add_library(translation_archive SHARED
  translation_xz_extract.cpp
  translation_xz_napi.cpp
)
target_link_libraries(translation_archive PRIVATE
  liblzma
  libace_napi.z.so
  libohcrypto.so
)
target_link_options(translation_archive PRIVATE "-Wl,--exclude-libs,ALL")
set_target_properties(translation_archive PROPERTIES OUTPUT_NAME "translation_archive")
