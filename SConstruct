# utilThirdParty - SCons Build System
# Builds third-party libraries for wxWidgets-based App Store applications

import os
import sys
import json
import platform
import subprocess
import tarfile
import zipfile
import urllib.request
import shutil
from pathlib import Path

# Directories
SCRIPT_DIR = Dir('.').abspath
DOWNLOADS_DIR = os.path.join(SCRIPT_DIR, 'downloads')
SOURCES_DIR = os.path.join(SCRIPT_DIR, 'sources')
BUILD_DIR = os.path.join(SCRIPT_DIR, 'build')
INSTALL_DIR = os.path.join(SCRIPT_DIR, 'install')

# Platform detection
PLATFORM = platform.system()  # Darwin, Windows, Linux
PLATFORM_INSTALL_DIR = os.path.join(INSTALL_DIR, PLATFORM)

# Ensure directories exist
for d in [DOWNLOADS_DIR, SOURCES_DIR, BUILD_DIR, PLATFORM_INSTALL_DIR]:
    os.makedirs(d, exist_ok=True)


def load_config():
    """Load and merge default config with project overrides."""
    # Load default config
    default_config_path = os.path.join(SCRIPT_DIR, 'config.default.json')
    with open(default_config_path, 'r') as f:
        config = json.load(f)

    # Look for project config in parent directory
    project_config_path = os.path.join(SCRIPT_DIR, '..', 'utilThirdParty.json')
    if os.path.exists(project_config_path):
        with open(project_config_path, 'r') as f:
            project_config = json.load(f)
        print(f"Found project config: {project_config_path}")
        return config, project_config

    print("No project config found, using defaults")
    return config, None


def get_option_value(lib_config, option_name, project_overrides=None):
    """Get the effective value for an option, respecting mandatory/locked values."""
    opt = lib_config['options'].get(option_name, {})

    if isinstance(opt, dict):
        default = opt.get('default')
        mandatory = opt.get('mandatory')

        # If mandatory, always use locked value
        if mandatory is not None:
            if isinstance(mandatory, bool) and mandatory:
                return opt.get('locked_value', default) if 'locked_value' in opt else default
            return mandatory

        # Check for project override
        if project_overrides and option_name in project_overrides:
            return project_overrides[option_name]

        return default
    else:
        # Simple value
        return opt


def download_file(url, dest_path):
    """Download a file if it doesn't exist."""
    if os.path.exists(dest_path):
        print(f"Using cached: {os.path.basename(dest_path)}")
        return

    print(f"Downloading: {url}")
    urllib.request.urlretrieve(url, dest_path)
    print(f"Downloaded: {os.path.basename(dest_path)}")


def extract_archive(archive_path, dest_dir):
    """Extract archive to destination."""
    print(f"Extracting: {os.path.basename(archive_path)}")

    if archive_path.endswith('.tar.bz2'):
        with tarfile.open(archive_path, 'r:bz2') as tar:
            tar.extractall(dest_dir)
    elif archive_path.endswith('.tar.gz') or archive_path.endswith('.tgz'):
        with tarfile.open(archive_path, 'r:gz') as tar:
            tar.extractall(dest_dir)
    elif archive_path.endswith('.zip'):
        with zipfile.ZipFile(archive_path, 'r') as zip_ref:
            zip_ref.extractall(dest_dir)
    else:
        raise ValueError(f"Unknown archive format: {archive_path}")


def apply_wxwidgets_patches(source_dir):
    """Apply necessary patches for wxWidgets."""
    # Patch libpng for macOS SDK compatibility
    pngpriv_path = os.path.join(source_dir, 'src', 'png', 'pngpriv.h')
    if os.path.exists(pngpriv_path):
        with open(pngpriv_path, 'r') as f:
            content = f.read()
        if '<fp.h>' in content:
            content = content.replace('#      include <fp.h>', '#      include <math.h>')
            with open(pngpriv_path, 'w') as f:
                f.write(content)
            print("Patched pngpriv.h (fp.h -> math.h)")

    # Patch archive.h for Clang compatibility
    archive_path = os.path.join(source_dir, 'include', 'wx', 'archive.h')
    if os.path.exists(archive_path):
        with open(archive_path, 'r') as f:
            content = f.read()
        if 'it.m_rep.AddRef()' in content:
            content = content.replace('it.m_rep.AddRef()', 'it.m_rep->AddRef()')
            content = content.replace('this->m_rep.UnRef()', 'this->m_rep->UnRef()')
            with open(archive_path, 'w') as f:
                f.write(content)
            print("Patched archive.h (pointer dereference)")


def build_wxwidgets(env, config, project_config):
    """Build wxWidgets library."""
    lib_config = config['wxwidgets']
    version = lib_config['version']

    # Get project overrides
    overrides = {}
    if project_config and 'overrides' in project_config:
        overrides = project_config.get('overrides', {}).get('wxwidgets', {})

    # Check if already built
    if PLATFORM == 'Darwin':
        marker = os.path.join(PLATFORM_INSTALL_DIR, 'lib', 'libwx_baseu-3.2.a')
    elif PLATFORM == 'Windows':
        marker = os.path.join(PLATFORM_INSTALL_DIR, 'lib', 'vc_x64_lib', 'wxbase32u.lib')
    else:
        marker = os.path.join(PLATFORM_INSTALL_DIR, 'lib', 'libwx_baseu-3.2.a')

    if os.path.exists(marker):
        print(f"wxWidgets {version} already built at {PLATFORM_INSTALL_DIR}")
        return PLATFORM_INSTALL_DIR

    # Download
    url = lib_config['url_template'].format(version=version)
    if PLATFORM == 'Windows':
        archive_name = f"wxWidgets-{version}.zip"
        url = url.replace('.tar.bz2', '.zip')
    else:
        archive_name = f"wxWidgets-{version}.tar.bz2"

    archive_path = os.path.join(DOWNLOADS_DIR, archive_name)
    download_file(url, archive_path)

    # Extract
    source_dir = os.path.join(SOURCES_DIR, f"wxWidgets-{version}")
    if not os.path.exists(source_dir):
        extract_archive(archive_path, SOURCES_DIR)

    # Apply patches
    apply_wxwidgets_patches(source_dir)

    # Build directory
    build_dir = os.path.join(BUILD_DIR, f"wxwidgets-{PLATFORM}")
    os.makedirs(build_dir, exist_ok=True)

    # Get effective options (respecting mandatory values)
    opts = lib_config['options']
    platform_opts = lib_config.get('platform_options', {}).get(PLATFORM.lower(), {})

    # Build CMake arguments
    cmake_args = [
        'cmake', source_dir,
        '-DCMAKE_BUILD_TYPE=Release',
        f'-DCMAKE_INSTALL_PREFIX={PLATFORM_INSTALL_DIR}',
        '-DBUILD_SHARED_LIBS=OFF',
        f'-DwxUSE_STL={_bool_cmake(get_option_value(lib_config, "stl", overrides))}',
        f'-DwxUSE_UNICODE={_bool_cmake(get_option_value(lib_config, "unicode", overrides))}',
        f'-DwxUSE_ACCESSIBILITY={_bool_cmake(get_option_value(lib_config, "accessibility", overrides))}',
        f'-DwxUSE_WEBVIEW={_bool_cmake(get_option_value(lib_config, "webview", overrides))}',
        f'-DwxUSE_MEDIACTRL={_bool_cmake(get_option_value(lib_config, "mediactrl", overrides))}',
        f'-DwxUSE_STC={_bool_cmake(get_option_value(lib_config, "stc", overrides))}',
        f'-DwxUSE_RIBBON={_bool_cmake(get_option_value(lib_config, "ribbon", overrides))}',
        f'-DwxUSE_PROPGRID={_bool_cmake(get_option_value(lib_config, "propgrid", overrides))}',
        f'-DwxUSE_AUI={_bool_cmake(get_option_value(lib_config, "aui", overrides))}',
        f'-DwxUSE_XRC={_bool_cmake(get_option_value(lib_config, "xrc", overrides))}',
        '-DwxBUILD_SAMPLES=OFF',
        '-DwxBUILD_TESTS=OFF',
        '-DwxBUILD_DEMOS=OFF',
        '-DCMAKE_CXX_STANDARD=17',
    ]

    # Handle library options (builtin/sys/off)
    libjpeg = get_option_value(lib_config, 'libjpeg', overrides)
    libpng = get_option_value(lib_config, 'libpng', overrides)
    libtiff = get_option_value(lib_config, 'libtiff', overrides)
    zlib = get_option_value(lib_config, 'zlib', overrides)
    expat = get_option_value(lib_config, 'expat', overrides)

    cmake_args.append(f'-DwxUSE_LIBJPEG={libjpeg}')
    cmake_args.append(f'-DwxUSE_LIBPNG={libpng}')
    cmake_args.append(f'-DwxUSE_LIBTIFF={"OFF" if not libtiff else libtiff}')
    cmake_args.append(f'-DwxUSE_ZLIB={zlib}')
    cmake_args.append(f'-DwxUSE_EXPAT={expat}')

    # Platform-specific options
    if PLATFORM == 'Darwin':
        deployment_target = platform_opts.get('deployment_target', {})
        if isinstance(deployment_target, dict):
            deployment_target = deployment_target.get('default', '10.15')
        architectures = platform_opts.get('architectures', {})
        if isinstance(architectures, dict):
            architectures = architectures.get('default', ['arm64', 'x86_64'])

        cmake_args.extend([
            f'-DCMAKE_OSX_DEPLOYMENT_TARGET={deployment_target}',
            f'-DCMAKE_OSX_ARCHITECTURES={";".join(architectures)}',
        ])
    elif PLATFORM == 'Windows':
        cmake_args.extend([
            '-G', 'Visual Studio 17 2022',
            '-A', 'x64',
            '-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded',
        ])
    else:  # Linux
        gtk_version = platform_opts.get('gtk_version', {})
        if isinstance(gtk_version, dict):
            gtk_version = gtk_version.get('default', 3)
        cmake_args.append(f'-DwxBUILD_TOOLKIT=gtk{gtk_version}')

    # Run CMake configure
    print(f"Configuring wxWidgets {version}...")
    subprocess.run(cmake_args, cwd=build_dir, check=True)

    # Build
    print(f"Building wxWidgets {version}...")
    build_cmd = ['cmake', '--build', '.', '--config', 'Release', '--parallel']
    subprocess.run(build_cmd, cwd=build_dir, check=True)

    # Install
    print(f"Installing wxWidgets {version}...")
    install_cmd = ['cmake', '--install', '.', '--config', 'Release']
    subprocess.run(install_cmd, cwd=build_dir, check=True)

    print(f"wxWidgets {version} installed to {PLATFORM_INSTALL_DIR}")
    return PLATFORM_INSTALL_DIR


def _bool_cmake(value):
    """Convert Python bool to CMake ON/OFF."""
    if isinstance(value, bool):
        return 'ON' if value else 'OFF'
    return str(value).upper()


# Load configuration
config, project_config = load_config()

# Determine which libraries to build
libraries_to_build = ['wxwidgets']  # Default
if project_config and 'libraries' in project_config:
    libraries_to_build = project_config['libraries']

print(f"Platform: {PLATFORM}")
print(f"Libraries to build: {libraries_to_build}")
print(f"Install directory: {PLATFORM_INSTALL_DIR}")
print()

# Create SCons environment
env = Environment()

# Build targets
if 'wxwidgets' in libraries_to_build:
    wxwidgets_target = env.Command(
        os.path.join(PLATFORM_INSTALL_DIR, '.wxwidgets_built'),
        [],
        lambda target, source, env: (
            build_wxwidgets(env, config, project_config),
            Path(str(target[0])).touch()
        )
    )
    env.Alias('wxwidgets', wxwidgets_target)
    Default(wxwidgets_target)

# Clean target
env.Clean('all', [BUILD_DIR, SOURCES_DIR])
