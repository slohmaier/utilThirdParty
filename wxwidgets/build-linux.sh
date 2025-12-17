#!/bin/bash
# Build wxWidgets static library for Linux
# Compatible with Ubuntu Snap distribution

set -e

WX_VERSION="3.2.4"
WX_URL="https://github.com/wxWidgets/wxWidgets/releases/download/v${WX_VERSION}/wxWidgets-${WX_VERSION}.tar.bz2"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build-linux"
INSTALL_DIR="${SCRIPT_DIR}/install/Linux"

echo "========================================"
echo "Building wxWidgets ${WX_VERSION} for Linux"
echo "Target: Ubuntu Snap compatible (static)"
echo "========================================"

# Check dependencies
echo "Checking build dependencies..."
MISSING_DEPS=""
for pkg in build-essential libgtk-3-dev libgl1-mesa-dev; do
    if ! dpkg -l | grep -q "^ii  $pkg"; then
        MISSING_DEPS="$MISSING_DEPS $pkg"
    fi
done

if [ -n "$MISSING_DEPS" ]; then
    echo "Missing dependencies:$MISSING_DEPS"
    echo "Install with: sudo apt install$MISSING_DEPS"
    exit 1
fi

# Create directories
mkdir -p "${BUILD_DIR}"
mkdir -p "${INSTALL_DIR}"

cd "${BUILD_DIR}"

# Download if needed
if [ ! -f "wxWidgets-${WX_VERSION}.tar.bz2" ]; then
    echo "Downloading wxWidgets..."
    curl -L -o "wxWidgets-${WX_VERSION}.tar.bz2" "${WX_URL}"
fi

# Extract if needed
if [ ! -d "wxWidgets-${WX_VERSION}" ]; then
    echo "Extracting..."
    tar xjf "wxWidgets-${WX_VERSION}.tar.bz2"
fi

cd "wxWidgets-${WX_VERSION}"

# Clean previous build
rm -rf build-static
mkdir build-static
cd build-static

echo "Configuring wxWidgets..."
../configure \
    --prefix="${INSTALL_DIR}" \
    --disable-shared \
    --enable-static \
    --enable-unicode \
    --enable-stl \
    --enable-std_containers \
    --enable-std_iostreams \
    --disable-debug \
    --enable-optimise \
    --with-gtk=3 \
    --with-libjpeg=builtin \
    --with-libpng=builtin \
    --with-libtiff=builtin \
    --with-zlib=builtin \
    --with-expat=builtin \
    --disable-webview \
    --enable-accessibility \
    CFLAGS="-fPIC" \
    CXXFLAGS="-fPIC -std=c++17"

echo "Building wxWidgets (this may take a while)..."
make -j$(nproc)

echo "Installing to ${INSTALL_DIR}..."
make install

echo "========================================"
echo "wxWidgets installed successfully!"
echo "Install location: ${INSTALL_DIR}"
echo ""
echo "To use in CMake:"
echo "  set(wxWidgets_ROOT \"${INSTALL_DIR}\")"
echo "  find_package(wxWidgets REQUIRED COMPONENTS core base)"
echo ""
echo "Or with wx-config:"
echo "  ${INSTALL_DIR}/bin/wx-config --cxxflags"
echo "  ${INSTALL_DIR}/bin/wx-config --libs"
echo "========================================"
