cmake_minimum_required(VERSION 3.5.0)
project(gesture_mnn)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(MNN SHARED IMPORTED)
set_target_properties(MNN PROPERTIES
  IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/../../../libs/${OHOS_ARCH}/libMNN.so"
)

add_library(gesture_mnn SHARED
  gesture_mnn_napi.cpp
  gesture_mnn_session.cpp
)
target_include_directories(gesture_mnn PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(gesture_mnn PRIVATE MNN libace_napi.z.so)
set_target_properties(gesture_mnn PROPERTIES
  BUILD_WITH_INSTALL_RPATH TRUE
  INSTALL_RPATH "\$ORIGIN"
)

add_library(segmentation_mnn SHARED
  segmentation_mnn_napi.cpp
  segmentation_mnn_session.cpp
)

add_library(object_detection_mnn SHARED
  object_detection_mnn_napi.cpp
  object_detection_mnn_session.cpp
)

add_library(style_transfer_mnn SHARED
  style_transfer_mnn_napi.cpp
  style_transfer_mnn_session.cpp
)
target_include_directories(style_transfer_mnn PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(style_transfer_mnn PRIVATE MNN libace_napi.z.so)
set_target_properties(style_transfer_mnn PROPERTIES
  BUILD_WITH_INSTALL_RPATH TRUE
  INSTALL_RPATH "\$ORIGIN"
)
target_include_directories(object_detection_mnn PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(object_detection_mnn PRIVATE MNN libace_napi.z.so)
set_target_properties(object_detection_mnn PROPERTIES
  BUILD_WITH_INSTALL_RPATH TRUE
  INSTALL_RPATH "\$ORIGIN"
)
target_include_directories(segmentation_mnn PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(segmentation_mnn PRIVATE MNN libace_napi.z.so)
set_target_properties(segmentation_mnn PROPERTIES
  BUILD_WITH_INSTALL_RPATH TRUE
  INSTALL_RPATH "\$ORIGIN"
)

add_library(ocr_mnn SHARED
  ocr_mnn_napi.cpp
  ocr_mnn_session.cpp
)
target_include_directories(ocr_mnn PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(ocr_mnn PRIVATE MNN libace_napi.z.so)
set_target_properties(ocr_mnn PROPERTIES
  BUILD_WITH_INSTALL_RPATH TRUE
  INSTALL_RPATH "\$ORIGIN"
)
