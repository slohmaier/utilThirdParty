# utilThirdParty

A collection of third-party libraries for wxWidgets-based App Store applications.

**Purpose**: Provides pre-configured static library builds for macOS App Store, Windows MS Store, and Ubuntu Snap distribution.

## Included Libraries

| Library | Version | Status | Description |
|---------|---------|--------|-------------|
| wxWidgets | 3.3.1 | Active | Cross-platform GUI framework with accessibility and dark mode |
| OpenCV | (planned) | Planned | Computer vision library |

## Build System

This repository uses **SCons** as its build system. SCons handles downloading, patching, configuring, and building each library with the appropriate settings for App Store compatibility.

### Quick Start

```bash
# Install SCons
pip install scons

# Build all libraries with default config
scons

# Build specific library
scons wxwidgets

# Clean build artifacts
scons -c
```

## Configuration

### config.default.json

The `config.default.json` file documents all available build options. This file should NOT be modified directly - it serves as a reference for available options.

```json
{
  "wxwidgets": {
    "version": "3.2.6",
    "options": {
      "shared": false,
      "unicode": true,
      "stl": true,
      "accessibility": true,
      "webview": false,
      "mediactrl": false,
      "stc": false,
      "ribbon": false,
      "propgrid": false,
      "aui": true,
      "xrc": true,
      "libjpeg": "builtin",
      "libpng": "builtin",
      "libtiff": false,
      "zlib": "builtin",
      "expat": "builtin"
    },
    "macos": {
      "deployment_target": "10.15",
      "architectures": ["arm64", "x86_64"]
    },
    "windows": {
      "runtime": "static"
    }
  },
  "opencv": {
    "version": "4.9.0",
    "options": {
      "shared": false,
      "with_java": false,
      "with_python": false,
      "with_gtk": false,
      "with_qt": false,
      "with_opengl": false,
      "with_cuda": false,
      "build_examples": false,
      "build_tests": false
    }
  }
}
```

### Project Configuration (utilThirdParty.json)

Projects using utilThirdParty provide a `utilThirdParty.json` file in their root directory to specify which libraries to build and any option overrides:

```json
{
  "libraries": ["wxwidgets"],
  "overrides": {
    "wxwidgets": {
      "aui": true,
      "xrc": true
    }
  }
}
```

## Mandatory Sandboxing Options

The following options are **enforced** for App Store compatibility and cannot be overridden:

### wxWidgets
- `shared`: false (static linking required)
- `webview`: false (WKWebView has sandbox issues)
- `mediactrl`: false (AVFoundation has sandbox issues)
- `accessibility`: true (required for App Store)

### OpenCV
- `shared`: false (static linking required)
- `with_gtk`: false (not needed, sandbox issues)
- `with_qt`: false (not needed)

## Directory Structure

```
utilThirdParty/
├── CLAUDE.md              # This file
├── config.default.json    # Default configuration reference
├── SConstruct             # Main SCons build file
├── site_scons/            # SCons helper modules
│   ├── wxwidgets.py       # wxWidgets build logic
│   └── opencv.py          # OpenCV build logic (planned)
├── wxwidgets/             # wxWidgets build scripts (legacy)
│   ├── build-macos.sh
│   ├── build-windows.ps1
│   └── CMakeLists.txt
├── downloads/             # Downloaded source archives (gitignored)
├── sources/               # Extracted source code (gitignored)
├── build/                 # Build directories (gitignored)
└── install/               # Installed libraries
    ├── Darwin/            # macOS universal binaries
    ├── Windows/           # Windows x64 libraries
    └── Linux/             # Linux libraries
```

## Integration with App Projects

### For BrailleKit (example)

BrailleKit uses this as a submodule at `third-party/`:

```bash
# In BrailleKit root
git submodule add git@github.com:slohmaier/utilThirdParty.git third-party
```

BrailleKit's `SConstruct` will:
1. Read `utilThirdParty.json` from BrailleKit root
2. Call `scons` in the `third-party/` submodule
3. Use msbuild (Windows) or xcodebuild (macOS) to build the app
4. `scons run` launches the built application

### Build Flow

```
BrailleKit/SConstruct
        │
        ├── Read utilThirdParty.json
        │
        ├── cd third-party && scons (build wxWidgets)
        │
        ├── Generate/update project files
        │   ├── Windows: .sln/.vcxproj
        │   └── macOS: .xcodeproj
        │
        ├── Build with native toolchain
        │   ├── Windows: msbuild BrailleKit.sln
        │   └── macOS: xcodebuild -project BrailleKit.xcodeproj
        │
        └── scons run → Launch .exe or .app
```

## Platform-Specific Notes

### macOS
- Requires Xcode Command Line Tools
- Builds universal binaries (arm64 + x86_64)
- Minimum deployment target: macOS 10.15
- Patches applied for SDK compatibility (libpng, archive.h)

### Windows
- Requires Visual Studio 2022 or later
- Uses static MSVC runtime (/MT) for MS Store
- x64 and arm64 targets supported

### Linux
- Requires GTK3 development packages
- Accessibility via ATK

## License

This repository contains build scripts only. Each library has its own license:
- wxWidgets: wxWindows Library Licence (LGPL-compatible, allows static linking)
- OpenCV: Apache 2.0
