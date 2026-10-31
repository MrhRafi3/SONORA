cmake_minimum_required(VERSION 3.10)

project(sonora_audio_engine VERSION 0.1.0 LANGUAGES CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(sonora_audio_engine SHARED
  engine.cpp
  dsp/biquad_filter.cpp
  dsp/preamp.cpp
  dsp/equalizer.cpp
  analysis/fft.cpp
  analysis/waveform.cpp
)

target_include_directories(sonora_audio_engine PUBLIC
  ../include
  .
)

target_compile_options(sonora_audio_engine PRIVATE
  -Wall
  -Wextra
  -Werror
  -O3
  -fPIC
  -fvisibility=hidden
)

set_target_properties(sonora_audio_engine PROPERTIES
  PUBLIC_HEADER ../include/sonora_audio_engine.h
  OUTPUT_NAME "sonora_audio_engine"
)

target_compile_definitions(sonora_audio_engine PUBLIC DART_SHARED_LIB)

if (ANDROID)
  # Support Android 15 16k page size
  target_link_options(sonora_audio_engine PRIVATE "-Wl,-z,max-page-size=16384")
  target_link_libraries(sonora_audio_engine log m)
endif()
