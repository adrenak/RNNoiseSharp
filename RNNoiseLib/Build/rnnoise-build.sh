#!/usr/bin/env bash

################################################################################
# RNNoise Universal Build Script (Shell)
#
# Usage: ./rnnoise-build.sh [flags]
#
# Flags:
#   --windows-x64          Build Windows x64
#   --windows-x86          Build Windows x86
#   --windows              Build all Windows architectures
#   --linux-x64            Build Linux x64
#   --linux-x86            Build Linux x86
#   --linux                Build all Linux architectures
#   --android-arm64        Build Android arm64-v8a
#   --android-arm32        Build Android armeabi-v7a
#   --android              Build all Android architectures
#   --macos                Build macOS universal binary
#   --ios                  Build iOS universal binary
#   --all                  Build all possible platforms (auto-detect)
#   --help                 Show this help message
#
# Examples:
#   ./rnnoise-build.sh --windows-x64 --linux-x64
#   ./rnnoise-build.sh --all
#   ./rnnoise-build.sh --android
################################################################################

set -e  # Exit on error (we'll handle errors manually)
set +e  # Actually, don't exit on error - we want to continue

# =============================================================================
# COLOR DEFINITIONS
# =============================================================================

if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'  # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# =============================================================================
# GLOBAL VARIABLES
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/intermediate"
BIN_DIR="$SCRIPT_DIR/bin"
SOURCE_DIR="$SCRIPT_DIR/../Source"
INCLUDE_DIR="$SCRIPT_DIR/../Include"

# Build request flags
BUILD_WINDOWS_X64=0
BUILD_WINDOWS_X86=0
BUILD_LINUX_X64=0
BUILD_LINUX_X86=0
BUILD_ANDROID_ARM64=0
BUILD_ANDROID_ARM32=0
BUILD_MACOS=0
BUILD_IOS=0
BUILD_ALL=0

# Build results (0=not attempted, 1=success, 2=failed, 3=unsupported)
declare -A BUILD_RESULTS
declare -A BUILD_MESSAGES

# Detect host OS
HOST_OS=""
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    HOST_OS="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    HOST_OS="macos"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
    HOST_OS="windows"
else
    HOST_OS="unknown"
fi

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

print_header() {
    echo ""
    echo "=============================================================================="
    echo -e "${BLUE}$1${NC}"
    echo "=============================================================================="
    echo ""
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

show_help() {
    echo "RNNoise Universal Build Script"
    echo ""
    echo "Usage: $0 [flags]"
    echo ""
    echo "Platform Flags:"
    echo "  --windows-x64          Build Windows x64"
    echo "  --windows-x86          Build Windows x86"
    echo "  --windows              Build all Windows architectures"
    echo "  --linux-x64            Build Linux x64"
    echo "  --linux-x86            Build Linux x86"
    echo "  --linux                Build all Linux architectures"
    echo "  --android-arm64        Build Android arm64-v8a"
    echo "  --android-arm32        Build Android armeabi-v7a"
    echo "  --android              Build all Android architectures"
    echo "  --macos                Build macOS universal binary"
    echo "  --ios                  Build iOS universal binary"
    echo "  --all                  Build all possible platforms (auto-detect)"
    echo "  --help                 Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --windows-x64 --linux-x64"
    echo "  $0 --all"
    echo "  $0 --android"
    echo ""
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Record build result
record_result() {
    local target="$1"
    local status="$2"  # 1=success, 2=failed, 3=unsupported
    local message="$3"

    BUILD_RESULTS["$target"]=$status
    BUILD_MESSAGES["$target"]="$message"
}

# =============================================================================
# PLATFORM DETECTION FUNCTIONS
# =============================================================================

can_build_windows() {
    if [[ "$HOST_OS" == "windows" ]]; then
        if command_exists cmake && command_exists cl.exe; then
            return 0
        else
            return 1
        fi
    elif [[ "$HOST_OS" == "macos" ]] || [[ "$HOST_OS" == "linux" ]]; then
        # Check for cross-compilation tools (MinGW)
        if command_exists x86_64-w64-mingw32-gcc; then
            return 0
        else
            return 1
        fi
    fi
    return 1
}

can_build_linux() {
    if [[ "$HOST_OS" == "linux" ]]; then
        if command_exists cmake && command_exists gcc; then
            return 0
        else
            return 1
        fi
    elif [[ "$HOST_OS" == "macos" ]]; then
        # Cross-compilation from macOS to Linux is complex
        return 1
    elif [[ "$HOST_OS" == "windows" ]]; then
        # Check for WSL
        if command_exists wsl; then
            return 0
        else
            return 1
        fi
    fi
    return 1
}

can_build_android() {
    # Check for Android NDK
    # Support both Unix (ndk-build) and Windows (ndk-build.cmd) NDK installations
    if [[ -n "$ANDROID_NDK_HOME" ]]; then
        if [[ -f "$ANDROID_NDK_HOME/ndk-build" ]] || [[ -f "$ANDROID_NDK_HOME/ndk-build.cmd" ]]; then
            return 0
        fi
    fi

    # Check common NDK locations
    local ndk_locations=(
        "$HOME/Android/Sdk/ndk"
        "$HOME/android-ndk"
        "$ANDROID_HOME/ndk"
        "/opt/android-ndk"
    )

    # If running from WSL, also check Windows user directories
    if [[ -d "/mnt/c/Users" ]]; then
        # Search all Windows user directories for Android NDK
        for user_dir in /mnt/c/Users/*/AppData/Local/Android/Sdk/ndk; do
            if [[ -d "$user_dir" ]]; then
                ndk_locations+=("$user_dir")
            fi
        done
    fi

    for location in "${ndk_locations[@]}"; do
        if [[ -d "$location" ]]; then
            # Look for either ndk-build (Unix) or ndk-build.cmd (Windows)
            local ndk_build=$(find "$location" -maxdepth 2 \( -name "ndk-build" -o -name "ndk-build.cmd" \) -type f 2>/dev/null | head -1)
            if [[ -n "$ndk_build" ]]; then
                export ANDROID_NDK_HOME="$(dirname "$ndk_build")"
                print_info "Auto-detected Android NDK at: $ANDROID_NDK_HOME"
                return 0
            fi
        fi
    done

    return 1
}

can_build_macos() {
    if [[ "$HOST_OS" == "macos" ]]; then
        if command_exists cmake && command_exists clang; then
            return 0
        else
            return 1
        fi
    fi
    return 1
}

can_build_ios() {
    if [[ "$HOST_OS" == "macos" ]]; then
        if command_exists xcodebuild; then
            return 0
        else
            return 1
        fi
    fi
    return 1
}

# =============================================================================
# BUILD FUNCTIONS
# =============================================================================

build_windows_x64() {
    local target="windows-x64"
    print_info "Building Windows x64..."

    if ! can_build_windows; then
        record_result "$target" 3 "Windows build tools not available on this host"
        print_error "Cannot build Windows x64: build tools not available"
        return 1
    fi

    local build_path="$BUILD_DIR/windows_x64"
    local output_path="$BIN_DIR/Windows/x64"

    mkdir -p "$build_path"
    mkdir -p "$output_path"

    cd "$build_path"

    if [[ "$HOST_OS" == "windows" ]]; then
        # Native Windows build with MSVC
        cmake "$SCRIPT_DIR" -G "Visual Studio 17 2022" -A x64 \
            -DCMAKE_BUILD_TYPE=Release \
            -DBUILD_SHARED_LIBS=ON \
            -DBUILD_STATIC_LIBS=ON

        if [[ $? -ne 0 ]]; then
            record_result "$target" 2 "CMake configuration failed"
            print_error "Windows x64: CMake configuration failed"
            return 1
        fi

        cmake --build . --config Release

        if [[ $? -ne 0 ]]; then
            record_result "$target" 2 "Compilation failed"
            print_error "Windows x64: Compilation failed"
            return 1
        fi

        cp -f Release/rnnoise.dll "$output_path/" 2>/dev/null || true
        cp -f Release/rnnoise.lib "$output_path/" 2>/dev/null || true
    else
        # Cross-compilation with MinGW (not fully implemented)
        record_result "$target" 3 "Cross-compilation from $HOST_OS not supported"
        print_error "Windows x64: Cross-compilation not supported on $HOST_OS"
        return 1
    fi

    if [[ -f "$output_path/rnnoise.dll" ]]; then
        record_result "$target" 1 "Built successfully"
        print_success "Windows x64 built successfully"
        return 0
    else
        record_result "$target" 2 "Output files not found"
        print_error "Windows x64: Output files not found"
        return 1
    fi
}

build_windows_x86() {
    local target="windows-x86"
    print_info "Building Windows x86..."

    if ! can_build_windows; then
        record_result "$target" 3 "Windows build tools not available on this host"
        print_error "Cannot build Windows x86: build tools not available"
        return 1
    fi

    local build_path="$BUILD_DIR/windows_x86"
    local output_path="$BIN_DIR/Windows/x86"

    mkdir -p "$build_path"
    mkdir -p "$output_path"

    cd "$build_path"

    if [[ "$HOST_OS" == "windows" ]]; then
        # Native Windows build with MSVC
        cmake "$SCRIPT_DIR" -G "Visual Studio 17 2022" -A Win32 \
            -DCMAKE_BUILD_TYPE=Release \
            -DBUILD_SHARED_LIBS=ON \
            -DBUILD_STATIC_LIBS=ON

        if [[ $? -ne 0 ]]; then
            record_result "$target" 2 "CMake configuration failed"
            print_error "Windows x86: CMake configuration failed"
            return 1
        fi

        cmake --build . --config Release

        if [[ $? -ne 0 ]]; then
            record_result "$target" 2 "Compilation failed"
            print_error "Windows x86: Compilation failed"
            return 1
        fi

        cp -f Release/rnnoise.dll "$output_path/" 2>/dev/null || true
        cp -f Release/rnnoise.lib "$output_path/" 2>/dev/null || true
    else
        record_result "$target" 3 "Cross-compilation from $HOST_OS not supported"
        print_error "Windows x86: Cross-compilation not supported on $HOST_OS"
        return 1
    fi

    if [[ -f "$output_path/rnnoise.dll" ]]; then
        record_result "$target" 1 "Built successfully"
        print_success "Windows x86 built successfully"
        return 0
    else
        record_result "$target" 2 "Output files not found"
        print_error "Windows x86: Output files not found"
        return 1
    fi
}

build_linux_x64() {
    local target="linux-x64"
    print_info "Building Linux x64..."

    if ! can_build_linux; then
        record_result "$target" 3 "Linux build tools not available on this host"
        print_error "Cannot build Linux x64: build tools not available"
        return 1
    fi

    local build_path="$BUILD_DIR/linux_x64"
    local output_path="$BIN_DIR/Linux/x86_64"

    mkdir -p "$build_path"
    mkdir -p "$output_path"

    cd "$build_path"

    if [[ "$HOST_OS" == "linux" ]]; then
        # Native Linux build
        cmake "$SCRIPT_DIR" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_C_FLAGS="-m64" \
            -DBUILD_SHARED_LIBS=ON \
            -DBUILD_STATIC_LIBS=ON

        if [[ $? -ne 0 ]]; then
            record_result "$target" 2 "CMake configuration failed"
            print_error "Linux x64: CMake configuration failed"
            return 1
        fi

        make -j$(nproc)

        if [[ $? -ne 0 ]]; then
            record_result "$target" 2 "Compilation failed"
            print_error "Linux x64: Compilation failed"
            return 1
        fi

        cp -f librnnoise.so* "$output_path/" 2>/dev/null || true
        cp -f librnnoise.a "$output_path/" 2>/dev/null || true
    elif [[ "$HOST_OS" == "windows" ]]; then
        # Build via WSL
        record_result "$target" 3 "WSL integration not yet implemented in this script"
        print_error "Linux x64: WSL builds should use WSL directly"
        return 1
    else
        record_result "$target" 3 "Cross-compilation from $HOST_OS not supported"
        print_error "Linux x64: Cross-compilation not supported on $HOST_OS"
        return 1
    fi

    if [[ -f "$output_path/librnnoise.so" ]]; then
        record_result "$target" 1 "Built successfully"
        print_success "Linux x64 built successfully"
        return 0
    else
        record_result "$target" 2 "Output files not found"
        print_error "Linux x64: Output files not found"
        return 1
    fi
}

build_linux_x86() {
    local target="linux-x86"
    print_info "Building Linux x86..."

    if ! can_build_linux; then
        record_result "$target" 3 "Linux build tools not available on this host"
        print_error "Cannot build Linux x86: build tools not available"
        return 1
    fi

    if [[ "$HOST_OS" != "linux" ]]; then
        record_result "$target" 3 "32-bit Linux builds only supported on native Linux"
        print_error "Linux x86: Only supported on native Linux host"
        return 1
    fi

    # Check for multilib support
    if ! dpkg -l | grep -q gcc-multilib; then
        record_result "$target" 3 "gcc-multilib not installed (required for 32-bit builds)"
        print_error "Linux x86: gcc-multilib not installed"
        print_info "Install with: sudo apt install gcc-multilib g++-multilib"
        return 1
    fi

    local build_path="$BUILD_DIR/linux_x86"
    local output_path="$BIN_DIR/Linux/x86"

    mkdir -p "$build_path"
    mkdir -p "$output_path"

    cd "$build_path"

    cmake "$SCRIPT_DIR" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_FLAGS="-m32" \
        -DCMAKE_CXX_FLAGS="-m32" \
        -DBUILD_SHARED_LIBS=ON \
        -DBUILD_STATIC_LIBS=ON

    if [[ $? -ne 0 ]]; then
        record_result "$target" 2 "CMake configuration failed"
        print_error "Linux x86: CMake configuration failed"
        return 1
    fi

    make -j$(nproc)

    if [[ $? -ne 0 ]]; then
        record_result "$target" 2 "Compilation failed"
        print_error "Linux x86: Compilation failed"
        return 1
    fi

    cp -f librnnoise.so* "$output_path/" 2>/dev/null || true
    cp -f librnnoise.a "$output_path/" 2>/dev/null || true

    if [[ -f "$output_path/librnnoise.so" ]]; then
        record_result "$target" 1 "Built successfully"
        print_success "Linux x86 built successfully"
        return 0
    else
        record_result "$target" 2 "Output files not found"
        print_error "Linux x86: Output files not found"
        return 1
    fi
}

build_android_arm64() {
    local target="android-arm64"
    print_info "Building Android arm64-v8a..."

    if ! can_build_android; then
        record_result "$target" 3 "Android NDK not found"
        print_error "Cannot build Android arm64: NDK not found"
        print_info "Set ANDROID_NDK_HOME or install NDK to common location"
        return 1
    fi

    local output_path="$BIN_DIR/Android/arm64-v8a"
    mkdir -p "$output_path"

    cd "$SCRIPT_DIR/jni"

    # Determine which ndk-build to use (Unix or Windows)
    local ndk_build_cmd="$ANDROID_NDK_HOME/ndk-build"
    local use_cmd_exe=false

    if [[ ! -f "$ndk_build_cmd" ]] && [[ -f "$ANDROID_NDK_HOME/ndk-build.cmd" ]]; then
        ndk_build_cmd="$ANDROID_NDK_HOME/ndk-build.cmd"
        # If it's a .cmd file and we're in WSL, we need to use cmd.exe
        if [[ -d "/mnt/c" ]]; then
            use_cmd_exe=true
        fi
    fi

    # Execute ndk-build (via cmd.exe if Windows .cmd from WSL)
    if [[ "$use_cmd_exe" == true ]]; then
        cmd.exe /c "$(wslpath -w "$ndk_build_cmd")" \
            NDK_PROJECT_PATH=. \
            APP_BUILD_SCRIPT=./Android.mk \
            APP_ABI=arm64-v8a \
            "NDK_LIBS_OUT=$(wslpath -w "$BIN_DIR/Android")" \
            "NDK_OUT=$(wslpath -w "$BUILD_DIR/android_arm64")"
    else
        "$ndk_build_cmd" \
            NDK_PROJECT_PATH=. \
            APP_BUILD_SCRIPT=./Android.mk \
            APP_ABI=arm64-v8a \
            NDK_LIBS_OUT="$BIN_DIR/Android" \
            NDK_OUT="$BUILD_DIR/android_arm64"
    fi

    if [[ $? -ne 0 ]]; then
        record_result "$target" 2 "ndk-build failed"
        print_error "Android arm64: ndk-build failed"
        return 1
    fi

    if [[ -f "$output_path/librnnoise.so" ]]; then
        record_result "$target" 1 "Built successfully"
        print_success "Android arm64-v8a built successfully"
        return 0
    else
        record_result "$target" 2 "Output files not found"
        print_error "Android arm64: Output files not found"
        return 1
    fi
}

build_android_arm32() {
    local target="android-arm32"
    print_info "Building Android armeabi-v7a..."

    if ! can_build_android; then
        record_result "$target" 3 "Android NDK not found"
        print_error "Cannot build Android arm32: NDK not found"
        print_info "Set ANDROID_NDK_HOME or install NDK to common location"
        return 1
    fi

    local output_path="$BIN_DIR/Android/armeabi-v7a"
    mkdir -p "$output_path"

    cd "$SCRIPT_DIR/jni"

    # Determine which ndk-build to use (Unix or Windows)
    local ndk_build_cmd="$ANDROID_NDK_HOME/ndk-build"
    local use_cmd_exe=false

    if [[ ! -f "$ndk_build_cmd" ]] && [[ -f "$ANDROID_NDK_HOME/ndk-build.cmd" ]]; then
        ndk_build_cmd="$ANDROID_NDK_HOME/ndk-build.cmd"
        # If it's a .cmd file and we're in WSL, we need to use cmd.exe
        if [[ -d "/mnt/c" ]]; then
            use_cmd_exe=true
        fi
    fi

    # Execute ndk-build (via cmd.exe if Windows .cmd from WSL)
    if [[ "$use_cmd_exe" == true ]]; then
        cmd.exe /c "$(wslpath -w "$ndk_build_cmd")" \
            NDK_PROJECT_PATH=. \
            APP_BUILD_SCRIPT=./Android.mk \
            APP_ABI=armeabi-v7a \
            "NDK_LIBS_OUT=$(wslpath -w "$BIN_DIR/Android")" \
            "NDK_OUT=$(wslpath -w "$BUILD_DIR/android_arm32")"
    else
        "$ndk_build_cmd" \
            NDK_PROJECT_PATH=. \
            APP_BUILD_SCRIPT=./Android.mk \
            APP_ABI=armeabi-v7a \
            NDK_LIBS_OUT="$BIN_DIR/Android" \
            NDK_OUT="$BUILD_DIR/android_arm32"
    fi

    if [[ $? -ne 0 ]]; then
        record_result "$target" 2 "ndk-build failed"
        print_error "Android arm32: ndk-build failed"
        return 1
    fi

    if [[ -f "$output_path/librnnoise.so" ]]; then
        record_result "$target" 1 "Built successfully"
        print_success "Android armeabi-v7a built successfully"
        return 0
    else
        record_result "$target" 2 "Output files not found"
        print_error "Android arm32: Output files not found"
        return 1
    fi
}

build_macos() {
    local target="macos"
    print_info "Building macOS universal binary..."

    if ! can_build_macos; then
        record_result "$target" 3 "macOS build tools not available (requires macOS)"
        print_error "Cannot build macOS: requires macOS host"
        return 1
    fi

    local build_path="$BUILD_DIR/macos"
    local output_path="$BIN_DIR/macOS"

    mkdir -p "$build_path"
    mkdir -p "$output_path"

    cd "$build_path"

    cmake "$SCRIPT_DIR" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_OSX_ARCHITECTURES="x86_64;arm64" \
        -DBUILD_SHARED_LIBS=ON \
        -DBUILD_STATIC_LIBS=ON

    if [[ $? -ne 0 ]]; then
        record_result "$target" 2 "CMake configuration failed"
        print_error "macOS: CMake configuration failed"
        return 1
    fi

    make -j$(sysctl -n hw.ncpu)

    if [[ $? -ne 0 ]]; then
        record_result "$target" 2 "Compilation failed"
        print_error "macOS: Compilation failed"
        return 1
    fi

    cp -f librnnoise.dylib "$output_path/" 2>/dev/null || true
    cp -f librnnoise.a "$output_path/" 2>/dev/null || true

    if [[ -f "$output_path/librnnoise.dylib" ]]; then
        record_result "$target" 1 "Built successfully"
        print_success "macOS universal binary built successfully"
        return 0
    else
        record_result "$target" 2 "Output files not found"
        print_error "macOS: Output files not found"
        return 1
    fi
}

build_ios() {
    local target="ios"
    print_info "Building iOS universal binary..."

    if ! can_build_ios; then
        record_result "$target" 3 "iOS build tools not available (requires macOS + Xcode)"
        print_error "Cannot build iOS: requires macOS + Xcode"
        return 1
    fi

    local build_path="$BUILD_DIR/ios"
    local output_path="$BIN_DIR/iOS"

    mkdir -p "$build_path"
    mkdir -p "$output_path"

    cd "$build_path"

    cmake "$SCRIPT_DIR" \
        -G Xcode \
        -DCMAKE_SYSTEM_NAME=iOS \
        -DCMAKE_OSX_ARCHITECTURES="arm64" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_STATIC_LIBS=ON

    if [[ $? -ne 0 ]]; then
        record_result "$target" 2 "CMake configuration failed"
        print_error "iOS: CMake configuration failed"
        return 1
    fi

    cmake --build . --config Release

    if [[ $? -ne 0 ]]; then
        record_result "$target" 2 "Compilation failed"
        print_error "iOS: Compilation failed"
        return 1
    fi

    cp -f Release/librnnoise.a "$output_path/" 2>/dev/null || true

    if [[ -f "$output_path/librnnoise.a" ]]; then
        record_result "$target" 1 "Built successfully"
        print_success "iOS universal binary built successfully"
        return 0
    else
        record_result "$target" 2 "Output files not found"
        print_error "iOS: Output files not found"
        return 1
    fi
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    print_header "RNNoise Universal Build Script"

    # Parse command-line arguments
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            --windows-x64)
                BUILD_WINDOWS_X64=1
                ;;
            --windows-x86)
                BUILD_WINDOWS_X86=1
                ;;
            --windows)
                BUILD_WINDOWS_X64=1
                BUILD_WINDOWS_X86=1
                ;;
            --linux-x64)
                BUILD_LINUX_X64=1
                ;;
            --linux-x86)
                BUILD_LINUX_X86=1
                ;;
            --linux)
                BUILD_LINUX_X64=1
                BUILD_LINUX_X86=1
                ;;
            --android-arm64)
                BUILD_ANDROID_ARM64=1
                ;;
            --android-arm32)
                BUILD_ANDROID_ARM32=1
                ;;
            --android)
                BUILD_ANDROID_ARM64=1
                BUILD_ANDROID_ARM32=1
                ;;
            --macos)
                BUILD_MACOS=1
                ;;
            --ios)
                BUILD_IOS=1
                ;;
            --all)
                BUILD_ALL=1
                BUILD_WINDOWS_X64=1
                BUILD_WINDOWS_X86=1
                BUILD_LINUX_X64=1
                BUILD_LINUX_X86=1
                BUILD_ANDROID_ARM64=1
                BUILD_ANDROID_ARM32=1
                BUILD_MACOS=1
                BUILD_IOS=1
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown flag: $1"
                echo ""
                show_help
                exit 1
                ;;
        esac
        shift
    done

    # Display host information
    print_info "Host OS: $HOST_OS"
    print_info "Script directory: $SCRIPT_DIR"
    echo ""

    # Execute builds
    [[ $BUILD_WINDOWS_X64 -eq 1 ]] && build_windows_x64
    [[ $BUILD_WINDOWS_X86 -eq 1 ]] && build_windows_x86
    [[ $BUILD_LINUX_X64 -eq 1 ]] && build_linux_x64
    [[ $BUILD_LINUX_X86 -eq 1 ]] && build_linux_x86
    [[ $BUILD_ANDROID_ARM64 -eq 1 ]] && build_android_arm64
    [[ $BUILD_ANDROID_ARM32 -eq 1 ]] && build_android_arm32
    [[ $BUILD_MACOS -eq 1 ]] && build_macos
    [[ $BUILD_IOS -eq 1 ]] && build_ios

    # Display build report
    print_header "BUILD REPORT"

    local success_count=0
    local failed_count=0
    local unsupported_count=0

    for target in "${!BUILD_RESULTS[@]}"; do
        local status=${BUILD_RESULTS[$target]}
        local message=${BUILD_MESSAGES[$target]}

        case $status in
            1)
                print_success "$target: $message"
                ((success_count++))
                ;;
            2)
                print_error "$target: $message"
                ((failed_count++))
                ;;
            3)
                print_warning "$target: $message"
                ((unsupported_count++))
                ;;
        esac
    done

    echo ""
    echo "Summary:"
    echo "  Successful: $success_count"
    echo "  Failed: $failed_count"
    echo "  Unsupported: $unsupported_count"
    echo ""

    if [[ $failed_count -gt 0 ]]; then
        print_error "Some builds failed!"
    elif [[ $success_count -gt 0 ]]; then
        print_success "All requested builds completed successfully!"
    else
        print_warning "No builds were successful"
    fi


    if [[ $failed_count -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Run main function
main "$@"
