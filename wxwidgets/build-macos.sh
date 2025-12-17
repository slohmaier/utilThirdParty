#!/bin/bash
# Build wxWidgets static libraries for macOS App Store
# Based on working TactiDesk build script
# Supports both Intel (x86_64) and Apple Silicon (arm64)

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build-macos"
INSTALL_DIR="$SCRIPT_DIR/install/Darwin"

WXWIDGETS_VERSION="3.2.6"
WXWIDGETS_NAME="wxWidgets-$WXWIDGETS_VERSION"
WXWIDGETS_ARCHIVE="$WXWIDGETS_NAME.tar.bz2"
WXWIDGETS_URL="https://github.com/wxWidgets/wxWidgets/releases/download/v$WXWIDGETS_VERSION/$WXWIDGETS_ARCHIVE"

echo "================================================"
echo "Building wxWidgets $WXWIDGETS_VERSION for macOS"
echo "Target: App Store compatible (static, universal)"
echo "================================================"

# Build universal binary for App Store
OSX_ARCH="arm64;x86_64"
echo "Building universal binary (arm64 + x86_64)"

# Check for CMake
if ! command -v cmake &> /dev/null; then
    echo "ERROR: CMake not found. Install with: brew install cmake"
    exit 1
fi

# Create directories
mkdir -p "$BUILD_DIR"
mkdir -p "$INSTALL_DIR"

# Download wxWidgets if not already present
cd "$BUILD_DIR"
if [ ! -f "$WXWIDGETS_ARCHIVE" ]; then
    echo "Downloading wxWidgets $WXWIDGETS_VERSION..."
    curl -L -o "$WXWIDGETS_ARCHIVE" "$WXWIDGETS_URL"
else
    echo "Using cached wxWidgets archive"
fi

# Extract if not already extracted
if [ ! -d "$WXWIDGETS_NAME" ]; then
    echo "Extracting wxWidgets..."
    tar -xjf "$WXWIDGETS_ARCHIVE"
else
    echo "Using existing wxWidgets source"
fi

cd "$WXWIDGETS_NAME"

# Patch the bundled libpng to fix macOS SDK compatibility
echo "Patching bundled libpng for macOS SDK compatibility..."
if [ -f "src/png/pngpriv.h" ]; then
    # Replace the problematic fp.h include with math.h (fp.h is for SGI IRIX systems from 1990s)
    sed -i.bak 's/#.*include <fp\.h>/#      include <math.h>/' src/png/pngpriv.h
    echo "libpng patched successfully"
fi

# Patch archive.h to fix pointer dereference bug (wxWidgets 3.2.x)
echo "Patching include/wx/archive.h for Clang compatibility..."
if [ -f "include/wx/archive.h" ]; then
    # Fix incorrect use of dot operator instead of arrow operator for pointer member
    sed -i.bak2 -e 's/it\.m_rep\.AddRef()/it.m_rep->AddRef()/' -e 's/this->m_rep\.UnRef()/this->m_rep->UnRef()/' include/wx/archive.h
    echo "archive.h patched successfully"
fi

# Create build directory
rm -rf build-static
mkdir -p build-static
cd build-static

# Check if already built
if [ -f "$INSTALL_DIR/lib/libwx_baseu-3.2.a" ]; then
    echo "wxWidgets already built. To rebuild, delete $INSTALL_DIR and run again."
    exit 0
fi

# Configure wxWidgets using CMake
echo "Configuring wxWidgets with CMake..."
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
    -DCMAKE_OSX_ARCHITECTURES="$OSX_ARCH" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=10.15 \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DBUILD_SHARED_LIBS=OFF \
    -DwxBUILD_MONOLITHIC=OFF \
    -DwxUSE_STL=ON \
    -DwxUSE_UNICODE=ON \
    -DwxUSE_STC=OFF \
    -DwxUSE_AUI=ON \
    -DwxUSE_XRC=ON \
    -DwxUSE_MEDIACTRL=OFF \
    -DwxUSE_WEBVIEW=OFF \
    -DwxUSE_LIBTIFF=OFF \
    -DwxUSE_LIBPNG=builtin \
    -DwxUSE_LIBJPEG=builtin \
    -DwxUSE_ZLIB=sys \
    -DwxUSE_EXPAT=builtin \
    -DwxBUILD_SAMPLES=OFF \
    -DwxBUILD_TESTS=OFF \
    -DwxBUILD_DEMOS=OFF \
    -DCMAKE_CXX_STANDARD=17

if [ $? -ne 0 ]; then
    echo "ERROR: CMake configuration failed"
    exit 1
fi

# Build wxWidgets
echo "Building wxWidgets (this may take 15-30 minutes)..."
make -j$(sysctl -n hw.ncpu)

if [ $? -ne 0 ]; then
    echo "ERROR: Build failed"
    exit 1
fi

# Install wxWidgets
echo "Installing wxWidgets to $INSTALL_DIR..."
make install

if [ $? -ne 0 ]; then
    echo "ERROR: Installation failed"
    exit 1
fi

echo ""
echo "================================================"
echo "wxWidgets build complete!"
echo "================================================"
echo "Install directory: $INSTALL_DIR"
echo "Libraries: $INSTALL_DIR/lib"
echo "Headers: $INSTALL_DIR/include"
echo ""
echo "To use in BrailleKit UI CMake:"
echo "  set(wxWidgets_ROOT \"$INSTALL_DIR\")"
echo ""
