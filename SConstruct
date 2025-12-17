# utilThirdParty - SCons Build System
# Builds third-party libraries for wxWidgets-based App Store applications
# NO CMAKE - uses native build systems (msbuild, xcodebuild, make)

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
    default_config_path = os.path.join(SCRIPT_DIR, 'config.default.json')
    with open(default_config_path, 'r') as f:
        config = json.load(f)

    project_config_path = os.path.join(SCRIPT_DIR, '..', 'utilThirdParty.json')
    if os.path.exists(project_config_path):
        with open(project_config_path, 'r') as f:
            project_config = json.load(f)
        print(f"Found project config: {project_config_path}")
        return config, project_config

    print("No project config found, using defaults")
    return config, None


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


def patch_vcxproj_for_static_crt(source_dir):
    """Patch wxWidgets to use static CRT (/MT instead of /MD)."""
    msw_dir = os.path.join(source_dir, 'build', 'msw')
    if not os.path.exists(msw_dir):
        return

    # wxWidgets 3.3+ uses wx_setup.props for CRT configuration
    setup_props = os.path.join(msw_dir, 'wx_setup.props')
    if os.path.exists(setup_props):
        with open(setup_props, 'r', encoding='utf-8') as f:
            content = f.read()

        original_content = content

        # Change default from dynamic to static CRT
        content = content.replace(
            '<wxRuntimeLibs>dynamic</wxRuntimeLibs>',
            '<wxRuntimeLibs>static</wxRuntimeLibs>'
        )

        if content != original_content:
            with open(setup_props, 'w', encoding='utf-8') as f:
                f.write(content)
            print("Patched wx_setup.props for static CRT (/MT)")
            return

    # Fallback for older wxWidgets versions: patch vcxproj files directly
    import glob
    vcxproj_files = glob.glob(os.path.join(msw_dir, '*.vcxproj'))

    patched_count = 0
    for vcxproj_path in vcxproj_files:
        with open(vcxproj_path, 'r', encoding='utf-8') as f:
            content = f.read()

        original_content = content

        # Replace DLL runtime with static runtime
        content = content.replace(
            '<RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>',
            '<RuntimeLibrary>MultiThreaded</RuntimeLibrary>'
        )
        content = content.replace(
            '<RuntimeLibrary>MultiThreadedDebugDLL</RuntimeLibrary>',
            '<RuntimeLibrary>MultiThreadedDebug</RuntimeLibrary>'
        )

        if content != original_content:
            with open(vcxproj_path, 'w', encoding='utf-8') as f:
                f.write(content)
            patched_count += 1

    if patched_count > 0:
        print(f"Patched {patched_count} vcxproj files for static CRT (/MT)")


def create_wx_setup_h(source_dir, options):
    """Create custom setup.h for wxWidgets build options."""
    setup_h_path = os.path.join(source_dir, 'include', 'wx', 'msw', 'setup.h')
    setup0_h_path = os.path.join(source_dir, 'include', 'wx', 'msw', 'setup0.h')

    # Copy setup0.h to setup.h if it doesn't exist
    if not os.path.exists(setup_h_path) and os.path.exists(setup0_h_path):
        shutil.copy(setup0_h_path, setup_h_path)

    if os.path.exists(setup_h_path):
        with open(setup_h_path, 'r') as f:
            content = f.read()

        # Apply our configuration options
        replacements = {
            # Disable features that cause sandbox issues
            '#define wxUSE_WEBVIEW 1': '#define wxUSE_WEBVIEW 0',
            '#define wxUSE_MEDIACTRL 1': '#define wxUSE_MEDIACTRL 0',
            # Disable features we don't need
            '#define wxUSE_STC 1': '#define wxUSE_STC 0' if not options.get('stc', False) else '#define wxUSE_STC 1',
            '#define wxUSE_RIBBON 1': '#define wxUSE_RIBBON 0' if not options.get('ribbon', False) else '#define wxUSE_RIBBON 1',
            '#define wxUSE_PROPGRID 1': '#define wxUSE_PROPGRID 0' if not options.get('propgrid', False) else '#define wxUSE_PROPGRID 1',
            # Enable features we need
            '#define wxUSE_STL 0': '#define wxUSE_STL 1' if options.get('stl', True) else '#define wxUSE_STL 0',
            '#define wxUSE_ACCESSIBILITY 0': '#define wxUSE_ACCESSIBILITY 1',
        }

        for old, new in replacements.items():
            content = content.replace(old, new)

        with open(setup_h_path, 'w') as f:
            f.write(content)
        print("Configured setup.h with custom options")


def find_msbuild():
    """Find MSBuild.exe on Windows."""
    # Try common Visual Studio installation paths
    vs_paths = [
        r"C:\Program Files\Microsoft Visual Studio\2022\Professional\MSBuild\Current\Bin\MSBuild.exe",
        r"C:\Program Files\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\MSBuild.exe",
        r"C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe",
        r"C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe",
        r"C:\Program Files\Microsoft Visual Studio\2019\Professional\MSBuild\Current\Bin\MSBuild.exe",
        r"C:\Program Files\Microsoft Visual Studio\2019\Enterprise\MSBuild\Current\Bin\MSBuild.exe",
        r"C:\Program Files\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe",
    ]

    for path in vs_paths:
        if os.path.exists(path):
            return path

    # Try vswhere if available
    vswhere = r"C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe"
    if os.path.exists(vswhere):
        try:
            result = subprocess.run([
                vswhere, '-latest', '-requires', 'Microsoft.Component.MSBuild',
                '-find', r'MSBuild\**\Bin\MSBuild.exe'
            ], capture_output=True, text=True)
            if result.returncode == 0 and result.stdout.strip():
                return result.stdout.strip().split('\n')[0]
        except:
            pass

    # Check if msbuild is in PATH
    msbuild_in_path = shutil.which('msbuild')
    if msbuild_in_path:
        return msbuild_in_path

    return None


def build_wxwidgets_windows(source_dir, config, project_config):
    """Build wxWidgets on Windows using native Visual Studio solution."""
    version = config['wxwidgets']['version']

    # Find MSBuild
    msbuild = find_msbuild()
    if not msbuild:
        print("ERROR: Could not find MSBuild.exe")
        print("Install Visual Studio 2022 or add MSBuild to PATH")
        return False
    print(f"Using MSBuild: {msbuild}")

    # Get overrides
    overrides = {}
    if project_config and 'overrides' in project_config:
        overrides = project_config.get('overrides', {}).get('wxwidgets', {})

    # Configure setup.h
    create_wx_setup_h(source_dir, overrides)

    # wxWidgets has pre-built VS solution files
    # wx_vc17.sln is for VS2022
    sln_path = os.path.join(source_dir, 'build', 'msw', 'wx_vc17.sln')

    if not os.path.exists(sln_path):
        # Try older solution file
        sln_path = os.path.join(source_dir, 'build', 'msw', 'wx_vc16.sln')

    if not os.path.exists(sln_path):
        print(f"ERROR: Could not find Visual Studio solution file")
        print(f"Looked in: {os.path.join(source_dir, 'build', 'msw')}")
        return False

    print(f"Building wxWidgets {version} using {os.path.basename(sln_path)}...")

    # Build both Debug and Release configurations
    configurations = [
        ('Debug', 'MultiThreadedDebug'),
        ('Release', 'MultiThreaded'),
    ]

    for config_name, runtime_lib in configurations:
        print(f"Building {config_name} configuration...")

        msbuild_args = [
            msbuild,
            sln_path,
            f'/p:Configuration={config_name}',
            '/p:Platform=x64',
            f'/p:RuntimeLibrary={runtime_lib}',
            '/p:UseOfMfc=false',
            '/m',  # Parallel build
            '/v:minimal',
        ]

        result = subprocess.run(msbuild_args, cwd=os.path.join(source_dir, 'build', 'msw'))

        if result.returncode != 0:
            print(f"ERROR: msbuild failed for {config_name}")
            return False

    # Copy built files to install directory
    print("Installing wxWidgets...")

    # Libraries are in lib/vc_x64_lib (static) or lib/vc_x64_dll (shared)
    src_lib_dir = os.path.join(source_dir, 'lib', 'vc_x64_lib')
    dst_lib_dir = os.path.join(PLATFORM_INSTALL_DIR, 'lib', 'vc_x64_lib')

    if os.path.exists(src_lib_dir):
        os.makedirs(dst_lib_dir, exist_ok=True)
        for f in os.listdir(src_lib_dir):
            if f.endswith('.lib') or f.endswith('.pdb'):
                src = os.path.join(src_lib_dir, f)
                dst = os.path.join(dst_lib_dir, f)
                shutil.copy2(src, dst)
        print(f"Copied libraries to {dst_lib_dir}")

        # Copy mswu (Release) and mswud (Debug) setup.h directories
        for subdir in ['mswu', 'mswud']:
            src_setup_dir = os.path.join(src_lib_dir, subdir)
            dst_setup_dir = os.path.join(dst_lib_dir, subdir)
            if os.path.exists(src_setup_dir):
                if os.path.exists(dst_setup_dir):
                    shutil.rmtree(dst_setup_dir)
                shutil.copytree(src_setup_dir, dst_setup_dir)
                print(f"Copied {subdir} setup directory")
    else:
        print(f"WARNING: Library directory not found: {src_lib_dir}")

    # Copy headers
    src_include = os.path.join(source_dir, 'include')
    dst_include = os.path.join(PLATFORM_INSTALL_DIR, 'include')

    if os.path.exists(dst_include):
        shutil.rmtree(dst_include)
    shutil.copytree(src_include, dst_include)

    print(f"Copied headers to {dst_include}")

    return True


def build_wxwidgets_macos(source_dir, config, project_config):
    """Build wxWidgets on macOS using configure/make."""
    version = config['wxwidgets']['version']
    build_dir = os.path.join(BUILD_DIR, 'wxwidgets-Darwin')
    os.makedirs(build_dir, exist_ok=True)

    # Get overrides
    overrides = {}
    if project_config and 'overrides' in project_config:
        overrides = project_config.get('overrides', {}).get('wxwidgets', {})

    configure_args = [
        os.path.join(source_dir, 'configure'),
        f'--prefix={PLATFORM_INSTALL_DIR}',
        '--disable-shared',
        '--enable-static',
        '--enable-unicode',
        '--enable-stl',
        '--enable-accessibility',
        '--disable-webview',
        '--disable-mediactrl',
        '--with-cocoa',
        '--with-macosx-version-min=10.15',
        '--enable-universal_binary=arm64,x86_64',
        '--with-libjpeg=builtin',
        '--with-libpng=builtin',
        '--with-zlib=builtin',
        '--with-expat=builtin',
        '--disable-debug',
        '--enable-optimise',
    ]

    # Add optional features
    if not overrides.get('stc', False):
        configure_args.append('--disable-stc')
    if not overrides.get('ribbon', False):
        configure_args.append('--disable-ribbon')
    if not overrides.get('propgrid', False):
        configure_args.append('--disable-propgrid')

    print(f"Configuring wxWidgets {version}...")
    result = subprocess.run(configure_args, cwd=build_dir)
    if result.returncode != 0:
        print("ERROR: configure failed")
        return False

    print(f"Building wxWidgets {version}...")
    cpu_count = os.cpu_count() or 4
    result = subprocess.run(['make', f'-j{cpu_count}'], cwd=build_dir)
    if result.returncode != 0:
        print("ERROR: make failed")
        return False

    print("Installing wxWidgets...")
    result = subprocess.run(['make', 'install'], cwd=build_dir)
    if result.returncode != 0:
        print("ERROR: make install failed")
        return False

    return True


def build_wxwidgets_linux(source_dir, config, project_config):
    """Build wxWidgets on Linux using configure/make."""
    version = config['wxwidgets']['version']
    build_dir = os.path.join(BUILD_DIR, 'wxwidgets-Linux')
    os.makedirs(build_dir, exist_ok=True)

    # Get overrides
    overrides = {}
    if project_config and 'overrides' in project_config:
        overrides = project_config.get('overrides', {}).get('wxwidgets', {})

    configure_args = [
        os.path.join(source_dir, 'configure'),
        f'--prefix={PLATFORM_INSTALL_DIR}',
        '--disable-shared',
        '--enable-static',
        '--enable-unicode',
        '--enable-stl',
        '--enable-accessibility',
        '--disable-webview',
        '--disable-mediactrl',
        '--with-gtk=3',
        '--with-libjpeg=builtin',
        '--with-libpng=builtin',
        '--with-zlib=builtin',
        '--with-expat=builtin',
        '--disable-debug',
        '--enable-optimise',
    ]

    if not overrides.get('stc', False):
        configure_args.append('--disable-stc')

    print(f"Configuring wxWidgets {version}...")
    result = subprocess.run(configure_args, cwd=build_dir)
    if result.returncode != 0:
        print("ERROR: configure failed")
        return False

    print(f"Building wxWidgets {version}...")
    cpu_count = os.cpu_count() or 4
    result = subprocess.run(['make', f'-j{cpu_count}'], cwd=build_dir)
    if result.returncode != 0:
        print("ERROR: make failed")
        return False

    print("Installing wxWidgets...")
    result = subprocess.run(['make', 'install'], cwd=build_dir)
    if result.returncode != 0:
        print("ERROR: make install failed")
        return False

    return True


def build_wxwidgets(env, config, project_config):
    """Build wxWidgets library using native build system."""
    lib_config = config['wxwidgets']
    version = lib_config['version']

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

    # wxWidgets ZIP may extract flat (no subdirectory) - detect and handle
    if not os.path.exists(source_dir):
        # Check if files are directly in SOURCES_DIR
        if os.path.exists(os.path.join(SOURCES_DIR, 'build', 'msw')):
            # Move files to expected subdirectory
            print(f"Moving extracted files to {source_dir}...")
            temp_dir = os.path.join(SOURCES_DIR, '_temp_wx')
            os.makedirs(temp_dir, exist_ok=True)
            for item in os.listdir(SOURCES_DIR):
                if item != '_temp_wx' and item != f"wxWidgets-{version}":
                    shutil.move(os.path.join(SOURCES_DIR, item), temp_dir)
            os.rename(temp_dir, source_dir)

    # Apply patches
    apply_wxwidgets_patches(source_dir)

    # Patch vcxproj files for static CRT on Windows
    if PLATFORM == 'Windows':
        patch_vcxproj_for_static_crt(source_dir)

    # Build using platform-native tools
    print(f"Building wxWidgets {version} for {PLATFORM}...")

    if PLATFORM == 'Windows':
        success = build_wxwidgets_windows(source_dir, config, project_config)
    elif PLATFORM == 'Darwin':
        success = build_wxwidgets_macos(source_dir, config, project_config)
    else:
        success = build_wxwidgets_linux(source_dir, config, project_config)

    if not success:
        raise RuntimeError("wxWidgets build failed")

    print(f"wxWidgets {version} installed to {PLATFORM_INSTALL_DIR}")
    return PLATFORM_INSTALL_DIR


# Load configuration
config, project_config = load_config()

# Determine which libraries to build
libraries_to_build = ['wxwidgets']
if project_config and 'libraries' in project_config:
    libraries_to_build = project_config['libraries']

print(f"Platform: {PLATFORM}")
print(f"Libraries to build: {libraries_to_build}")
print(f"Install directory: {PLATFORM_INSTALL_DIR}")
print()

# Create SCons environment
env = Environment()

def build_wxwidgets_action(target, source, env):
    """SCons action to build wxWidgets."""
    build_wxwidgets(env, config, project_config)
    Path(str(target[0])).touch()
    return 0  # Success


# Build targets
if 'wxwidgets' in libraries_to_build:
    wxwidgets_target = env.Command(
        os.path.join(PLATFORM_INSTALL_DIR, '.wxwidgets_built'),
        [],
        build_wxwidgets_action
    )
    env.Alias('wxwidgets', wxwidgets_target)
    Default(wxwidgets_target)

# Clean target
env.Clean('all', [BUILD_DIR, SOURCES_DIR])
