cmake_minimum_required(VERSION 3.10)
project(rnnoise VERSION 1.0.0 LANGUAGES C)

# Options
option(BUILD_SHARED_LIBS "Build shared library" ON)
option(BUILD_STATIC_LIBS "Build static library" ON)

# Set C standard
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Source files
set(RNNOISE_SOURCES
    ../Source/rnn_reader.c
    ../Source/rnn_data.c
    ../Source/pitch.c
    ../Source/rnn.c
    ../Source/denoise.c
    ../Source/kiss_fft.c
    ../Source/celt_lpc.c
)

# Header files
set(RNNOISE_HEADERS
    ../Include/rnnoise.h
    ../Source/rnn_data.h
    ../Source/tansig_table.h
    ../Source/pitch.h
    ../Source/rnn.h
    ../Source/kiss_fft.h
    ../Source/opus_types.h
    ../Source/celt_lpc.h
    ../Source/common.h
    ../Source/_kiss_fft_guts.h
    ../Source/arch.h
)

# Include directories
include_directories(
    ../Source
    ../Include
)

# Compiler flags
add_compile_definitions(
    COMPILE_OPUS
    RNNOISE_BUILD
)

if(MSVC)
    add_compile_definitions(_CRT_SECURE_NO_WARNINGS)
    add_compile_options(/W3 /O2)
else()
    add_compile_options(-Wall -O3 -fPIC)
endif()

# Shared library
if(BUILD_SHARED_LIBS)
    add_library(rnnoise_shared SHARED ${RNNOISE_SOURCES} ${RNNOISE_HEADERS})
    set_target_properties(rnnoise_shared PROPERTIES
        OUTPUT_NAME rnnoise
        VERSION ${PROJECT_VERSION}
        SOVERSION 1
        PUBLIC_HEADER ../Include/rnnoise.h
    )

    if(WIN32)
        target_compile_definitions(rnnoise_shared PRIVATE DLL_EXPORT)
    elseif(UNIX)
        set_target_properties(rnnoise_shared PROPERTIES
            C_VISIBILITY_PRESET hidden
        )
    endif()

    install(TARGETS rnnoise_shared
        LIBRARY DESTINATION lib
        RUNTIME DESTINATION bin
        PUBLIC_HEADER DESTINATION include
    )
endif()

# Static library
if(BUILD_STATIC_LIBS)
    add_library(rnnoise_static STATIC ${RNNOISE_SOURCES} ${RNNOISE_HEADERS})
    set_target_properties(rnnoise_static PROPERTIES
        OUTPUT_NAME rnnoise
        PUBLIC_HEADER ../Include/rnnoise.h
    )

    install(TARGETS rnnoise_static
        ARCHIVE DESTINATION lib
        PUBLIC_HEADER DESTINATION include
    )
endif()

# Platform-specific settings
if(APPLE)
    set_target_properties(rnnoise_shared PROPERTIES
        MACOSX_RPATH ON
        INSTALL_NAME_DIR "@rpath"
    )
endif()

# Print build configuration
message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "Build shared library: ${BUILD_SHARED_LIBS}")
message(STATUS "Build static library: ${BUILD_STATIC_LIBS}")
message(STATUS "System: ${CMAKE_SYSTEM_NAME}")
message(STATUS "Processor: ${CMAKE_SYSTEM_PROCESSOR}")
