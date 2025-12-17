# wxWidgets Static Build Configuration
# Downloads and builds wxWidgets for static linking
# Targets: macOS App Store, Windows MS Store, Ubuntu Snap

cmake_minimum_required(VERSION 3.20)
project(wxWidgets_static_build)

set(WX_VERSION "3.2.4")
set(WX_URL "https://github.com/wxWidgets/wxWidgets/releases/download/v${WX_VERSION}/wxWidgets-${WX_VERSION}.tar.bz2")
set(WX_SHA256 "0640e1ab716db5af2ecb7389d0de60e8f0a1c9b1a9b8c3e1d3c8e3e5b7e3d8a1") # Update with actual hash

include(ExternalProject)

# Platform-specific configuration
if(APPLE)
    set(WX_PLATFORM_FLAGS
        --with-macosx-version-min=10.15
        --with-cocoa
        --enable-universal_binary=arm64,x86_64
        --with-libjpeg=builtin
        --with-libpng=builtin
        --with-libtiff=builtin
        --with-zlib=builtin
        --with-expat=builtin
        # App Store requirements
        --disable-mediactrl          # AVFoundation issues
        --disable-webview            # WKWebView sandbox issues
        --enable-accessibility
    )
elseif(WIN32)
    set(WX_PLATFORM_FLAGS
        # Windows MS Store compatible
        --with-libjpeg=builtin
        --with-libpng=builtin
        --with-libtiff=builtin
        --with-zlib=builtin
        --with-expat=builtin
        --enable-accessibility
    )
else()
    # Linux (Ubuntu Snap compatible)
    set(WX_PLATFORM_FLAGS
        --with-gtk=3
        --with-libjpeg=builtin
        --with-libpng=builtin
        --with-libtiff=builtin
        --with-zlib=builtin
        --with-expat=builtin
        --enable-accessibility
    )
endif()

set(WX_INSTALL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/install/${CMAKE_SYSTEM_NAME}")

ExternalProject_Add(wxWidgets_static
    URL ${WX_URL}
    PREFIX ${CMAKE_CURRENT_BINARY_DIR}/wxWidgets
    CONFIGURE_COMMAND <SOURCE_DIR>/configure
        --prefix=${WX_INSTALL_DIR}
        --disable-shared
        --enable-static
        --enable-unicode
        --enable-stl
        --enable-std_containers
        --enable-std_iostreams
        --disable-debug
        --enable-optimise
        ${WX_PLATFORM_FLAGS}
    BUILD_COMMAND make -j${CMAKE_BUILD_PARALLEL_LEVEL}
    INSTALL_COMMAND make install
    BUILD_IN_SOURCE 0
)

message(STATUS "wxWidgets will be installed to: ${WX_INSTALL_DIR}")
message(STATUS "After build, use: ${WX_INSTALL_DIR}/bin/wx-config --cxxflags --libs")
