# Build wxWidgets static library for Windows MS Store
# Run from Visual Studio Developer PowerShell

param(
    [string]$Arch = "x64"  # x64 or arm64
)

$ErrorActionPreference = "Stop"

$WX_VERSION = "3.2.4"
$WX_URL = "https://github.com/wxWidgets/wxWidgets/releases/download/v$WX_VERSION/wxWidgets-$WX_VERSION.zip"
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$BUILD_DIR = Join-Path $SCRIPT_DIR "build-windows"
$INSTALL_DIR = Join-Path $SCRIPT_DIR "install\Windows"

Write-Host "========================================"
Write-Host "Building wxWidgets $WX_VERSION for Windows"
Write-Host "Target: MS Store compatible (static)"
Write-Host "Architecture: $Arch"
Write-Host "========================================"

# Create directories
New-Item -ItemType Directory -Force -Path $BUILD_DIR | Out-Null
New-Item -ItemType Directory -Force -Path $INSTALL_DIR | Out-Null

Set-Location $BUILD_DIR

# Download if needed
$zipFile = "wxWidgets-$WX_VERSION.zip"
if (-not (Test-Path $zipFile)) {
    Write-Host "Downloading wxWidgets..."
    Invoke-WebRequest -Uri $WX_URL -OutFile $zipFile
}

# Extract if needed
$srcDir = "wxWidgets-$WX_VERSION"
if (-not (Test-Path $srcDir)) {
    Write-Host "Extracting..."
    Expand-Archive -Path $zipFile -DestinationPath . -Force
}

Set-Location $srcDir

# Build using CMake for better MS Store compatibility
$cmakeBuildDir = "build-cmake-$Arch"
New-Item -ItemType Directory -Force -Path $cmakeBuildDir | Out-Null
Set-Location $cmakeBuildDir

Write-Host "Configuring wxWidgets with CMake..."

$cmakeArgs = @(
    "..",
    "-G", "Visual Studio 17 2022",
    "-A", $Arch,
    "-DCMAKE_INSTALL_PREFIX=$INSTALL_DIR",
    "-DwxBUILD_SHARED=OFF",
    "-DwxUSE_STL=ON",
    "-DwxUSE_UNICODE=ON",
    "-DwxUSE_ACCESSIBILITY=ON",
    "-DwxUSE_WEBVIEW=OFF",          # Sandbox issues
    "-DwxUSE_MEDIACTRL=OFF",        # Sandbox issues
    "-DwxUSE_STC=OFF",              # Not needed, reduces size
    "-DwxUSE_RIBBON=OFF",           # Not needed
    "-DwxUSE_PROPGRID=OFF",         # Not needed
    "-DwxUSE_AUI=ON",
    "-DwxUSE_XRC=ON",
    "-DwxBUILD_OPTIMISE=ON",
    "-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded"  # Static CRT for store
)

& cmake $cmakeArgs
if ($LASTEXITCODE -ne 0) { throw "CMake configure failed" }

Write-Host "Building wxWidgets (this may take a while)..."
& cmake --build . --config Release --parallel
if ($LASTEXITCODE -ne 0) { throw "Build failed" }

Write-Host "Installing to $INSTALL_DIR..."
& cmake --install . --config Release
if ($LASTEXITCODE -ne 0) { throw "Install failed" }

Write-Host "========================================"
Write-Host "wxWidgets installed successfully!"
Write-Host "Install location: $INSTALL_DIR"
Write-Host ""
Write-Host "To use in CMake:"
Write-Host "  set(wxWidgets_ROOT `"$INSTALL_DIR`")"
Write-Host "  find_package(wxWidgets REQUIRED COMPONENTS core base)"
Write-Host "========================================"
