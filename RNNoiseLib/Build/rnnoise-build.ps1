################################################################################
# RNNoise Universal Build Script (PowerShell)
#
# Usage: .\rnnoise-build.ps1 [flags]
#
# Flags:
#   -WindowsX64            Build Windows x64
#   -WindowsX86            Build Windows x86
#   -Windows               Build all Windows architectures
#   -LinuxX64              Build Linux x64
#   -LinuxX86              Build Linux x86
#   -Linux                 Build all Linux architectures
#   -AndroidArm64          Build Android arm64-v8a
#   -AndroidArm32          Build Android armeabi-v7a
#   -Android               Build all Android architectures
#   -MacOS                 Build macOS universal binary
#   -IOS                   Build iOS universal binary
#   -All                   Build all possible platforms (auto-detect)
#   -Help                  Show this help message
#
# Examples:
#   .\rnnoise-build.ps1 -WindowsX64 -LinuxX64
#   .\rnnoise-build.ps1 -All
#   .\rnnoise-build.ps1 -Android
################################################################################

param(
    [switch]$WindowsX64,
    [switch]$WindowsX86,
    [switch]$Windows,
    [switch]$LinuxX64,
    [switch]$LinuxX86,
    [switch]$Linux,
    [switch]$AndroidArm64,
    [switch]$AndroidArm32,
    [switch]$Android,
    [switch]$MacOS,
    [switch]$IOS,
    [switch]$All,
    [switch]$Help
)

# =============================================================================
# GLOBAL VARIABLES
# =============================================================================

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BuildDir = Join-Path $ScriptDir "intermediate"
$BinDir = Join-Path $ScriptDir "bin"
$SourceDir = Join-Path $ScriptDir "..\Source"
$IncludeDir = Join-Path $ScriptDir "..\Include"

# Build results (0=not attempted, 1=success, 2=failed, 3=unsupported)
$BuildResults = @{}
$BuildMessages = @{}

# Detect host OS
$HostOS = "unknown"
if ($IsWindows -or $env:OS -eq "Windows_NT") {
    $HostOS = "windows"
} elseif ($IsLinux) {
    $HostOS = "linux"
} elseif ($IsMacOS) {
    $HostOS = "macos"
}

# Success/failure counters
$SuccessCount = 0
$FailedCount = 0
$UnsupportedCount = 0

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "==============================================================================" -ForegroundColor Blue
    Write-Host $Message -ForegroundColor Blue
    Write-Host "==============================================================================" -ForegroundColor Blue
    Write-Host ""
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-Failure {
    param([string]$Message)
    Write-Host "[ERROR] " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

function Write-Warning-Custom {
    param([string]$Message)
    Write-Host "[WARN] " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] " -ForegroundColor Cyan -NoNewline
    Write-Host $Message
}

function Show-Help {
    Write-Host "RNNoise Universal Build Script (PowerShell)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage: .\rnnoise-build.ps1 [flags]"
    Write-Host ""
    Write-Host "Platform Flags:"
    Write-Host "  -WindowsX64            Build Windows x64"
    Write-Host "  -WindowsX86            Build Windows x86"
    Write-Host "  -Windows               Build all Windows architectures"
    Write-Host "  -LinuxX64              Build Linux x64"
    Write-Host "  -LinuxX86              Build Linux x86"
    Write-Host "  -Linux                 Build all Linux architectures"
    Write-Host "  -AndroidArm64          Build Android arm64-v8a"
    Write-Host "  -AndroidArm32          Build Android armeabi-v7a"
    Write-Host "  -Android               Build all Android architectures"
    Write-Host "  -MacOS                 Build macOS universal binary"
    Write-Host "  -IOS                   Build iOS universal binary"
    Write-Host "  -All                   Build all possible platforms (auto-detect)"
    Write-Host "  -Help                  Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\rnnoise-build.ps1 -WindowsX64 -LinuxX64"
    Write-Host "  .\rnnoise-build.ps1 -All"
    Write-Host "  .\rnnoise-build.ps1 -Android"
    Write-Host ""
}

function Test-CommandExists {
    param([string]$Command)
    try {
        if (Get-Command $Command -ErrorAction Stop) {
            return $true
        }
    } catch {
        return $false
    }
    return $false
}

function Record-Result {
    param(
        [string]$Target,
        [int]$Status,  # 1=success, 2=failed, 3=unsupported
        [string]$Message
    )

    $BuildResults[$Target] = $Status
    $BuildMessages[$Target] = $Message
}

# =============================================================================
# PLATFORM DETECTION FUNCTIONS
# =============================================================================

function Test-CanBuildWindows {
    if ($HostOS -eq "windows") {
        # Check if CMake exists
        if (-not (Test-CommandExists "cmake")) {
            return $false
        }

        # Check for MinGW (gcc/g++)
        if ((Test-CommandExists "gcc") -and (Test-CommandExists "g++")) {
            return $true
        }

        # Check for MSVC (cl) - might not be in PATH unless in VS dev prompt
        if (Test-CommandExists "cl") {
            return $true
        }

        # Try to find Visual Studio using vswhere (more reliable)
        $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
        if (Test-Path $vswhere) {
            $vsPath = & $vswhere -latest -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
            if ($vsPath) {
                return $true
            }
        }
    }
    return $false
}

function Test-CanBuildLinux {
    if ($HostOS -eq "linux") {
        if ((Test-CommandExists "cmake") -and (Test-CommandExists "gcc")) {
            return $true
        }
    } elseif ($HostOS -eq "windows") {
        # Check for WSL
        if (Test-CommandExists "wsl") {
            return $true
        }
    }
    return $false
}

function Test-CanBuildAndroid {
    # Check for Android NDK
    if ($env:ANDROID_NDK_HOME -and ((Test-Path "$env:ANDROID_NDK_HOME\ndk-build.cmd") -or (Test-Path "$env:ANDROID_NDK_HOME/ndk-build"))) {
        return $true
    }

    # Check common NDK locations
    $ndkLocations = @(
        "$env:HOME/Android/Sdk/ndk",
        "$env:HOME/android-ndk",
        "$env:ANDROID_HOME/ndk",
        "/opt/android-ndk"
    )

    foreach ($location in $ndkLocations) {
        if (Test-Path $location) {
            $ndkBuild = Get-ChildItem -Path $location -Filter "ndk-build*" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($ndkBuild) {
                $env:ANDROID_NDK_HOME = $ndkBuild.DirectoryName
                return $true
            }
        }
    }

    return $false
}

function Test-CanBuildMacOS {
    if ($HostOS -eq "macos") {
        if ((Test-CommandExists "cmake") -and (Test-CommandExists "clang")) {
            return $true
        }
    }
    return $false
}

function Test-CanBuildIOS {
    if ($HostOS -eq "macos") {
        if (Test-CommandExists "xcodebuild") {
            return $true
        }
    }
    return $false
}

function Get-WindowsCMakeGenerator {
    # Check for MinGW
    if ((Test-CommandExists "gcc") -and (Test-CommandExists "g++")) {
        return "MinGW Makefiles"
    }

    # Try to find Visual Studio using vswhere
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswhere) {
        $vsPath = & $vswhere -latest -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
        if ($vsPath) {
            # Get the VS version
            $vsVersion = & $vswhere -latest -property catalog_productDisplayVersion 2>$null
            if ($vsVersion -match "^(\d+)") {
                $majorVersion = $matches[1]
                $year = switch ($majorVersion) {
                    "17" { "2022" }
                    "16" { "2019" }
                    "15" { "2017" }
                    default { "17 2022" }
                }
                return "Visual Studio $majorVersion $year"
            }
        }
    }

    # Fallback to Ninja if available
    if (Test-CommandExists "ninja") {
        return "Ninja"
    }

    # Last resort - try default Visual Studio
    return "Visual Studio 17 2022"
}

# =============================================================================
# BUILD FUNCTIONS
# =============================================================================

function Build-WindowsX64 {
    $target = "windows-x64"
    Write-Info "Building Windows x64..."

    if (-not (Test-CanBuildWindows)) {
        Record-Result $target 3 "Windows build tools not available on this host"
        Write-Failure "Cannot build Windows x64: build tools not available"
        return
    }

    $buildPath = Join-Path $BuildDir "windows_x64"
    $outputPath = Join-Path $BinDir "Windows\x64"

    New-Item -ItemType Directory -Force -Path $buildPath | Out-Null
    New-Item -ItemType Directory -Force -Path $outputPath | Out-Null

    Push-Location $buildPath

    try {
        # Detect best CMake generator
        $generator = Get-WindowsCMakeGenerator
        Write-Info "Using CMake generator: $generator"

        # Configure with CMake
        if ($generator -like "Visual Studio*") {
            & cmake $ScriptDir -G $generator -A x64 `
                -DCMAKE_BUILD_TYPE=Release `
                -DBUILD_SHARED_LIBS=ON `
                -DBUILD_STATIC_LIBS=ON
        } else {
            & cmake $ScriptDir -G $generator `
                -DCMAKE_BUILD_TYPE=Release `
                -DBUILD_SHARED_LIBS=ON `
                -DBUILD_STATIC_LIBS=ON
        }

        if ($LASTEXITCODE -ne 0) {
            Record-Result $target 2 "CMake configuration failed"
            Write-Failure "Windows x64: CMake configuration failed"
            return
        }

        # Build
        & cmake --build . --config Release

        if ($LASTEXITCODE -ne 0) {
            Record-Result $target 2 "Compilation failed"
            Write-Failure "Windows x64: Compilation failed"
            return
        }

        # Copy output files
        Copy-Item -Path "Release\rnnoise.dll" -Destination $outputPath -Force -ErrorAction SilentlyContinue
        Copy-Item -Path "Release\rnnoise.lib" -Destination $outputPath -Force -ErrorAction SilentlyContinue

        if (Test-Path (Join-Path $outputPath "rnnoise.dll")) {
            Record-Result $target 1 "Built successfully"
            Write-Success "Windows x64 built successfully"
        } else {
            Record-Result $target 2 "Output files not found"
            Write-Failure "Windows x64: Output files not found"
        }
    } finally {
        Pop-Location
    }
}

function Build-WindowsX86 {
    $target = "windows-x86"
    Write-Info "Building Windows x86..."

    if (-not (Test-CanBuildWindows)) {
        Record-Result $target 3 "Windows build tools not available on this host"
        Write-Failure "Cannot build Windows x86: build tools not available"
        return
    }

    $buildPath = Join-Path $BuildDir "windows_x86"
    $outputPath = Join-Path $BinDir "Windows\x86"

    New-Item -ItemType Directory -Force -Path $buildPath | Out-Null
    New-Item -ItemType Directory -Force -Path $outputPath | Out-Null

    Push-Location $buildPath

    try {
        # Detect best CMake generator
        $generator = Get-WindowsCMakeGenerator
        Write-Info "Using CMake generator: $generator"

        # Configure with CMake
        if ($generator -like "Visual Studio*") {
            & cmake $ScriptDir -G $generator -A Win32 `
                -DCMAKE_BUILD_TYPE=Release `
                -DBUILD_SHARED_LIBS=ON `
                -DBUILD_STATIC_LIBS=ON
        } else {
            # For MinGW/Ninja, we can't easily do 32-bit, so skip or warn
            Write-Warning-Custom "x86 builds with $generator may require additional setup"
            & cmake $ScriptDir -G $generator `
                -DCMAKE_BUILD_TYPE=Release `
                -DBUILD_SHARED_LIBS=ON `
                -DBUILD_STATIC_LIBS=ON
        }

        if ($LASTEXITCODE -ne 0) {
            Record-Result $target 2 "CMake configuration failed"
            Write-Failure "Windows x86: CMake configuration failed"
            return
        }

        # Build
        & cmake --build . --config Release

        if ($LASTEXITCODE -ne 0) {
            Record-Result $target 2 "Compilation failed"
            Write-Failure "Windows x86: Compilation failed"
            return
        }

        # Copy output files
        Copy-Item -Path "Release\rnnoise.dll" -Destination $outputPath -Force -ErrorAction SilentlyContinue
        Copy-Item -Path "Release\rnnoise.lib" -Destination $outputPath -Force -ErrorAction SilentlyContinue

        if (Test-Path (Join-Path $outputPath "rnnoise.dll")) {
            Record-Result $target 1 "Built successfully"
            Write-Success "Windows x86 built successfully"
        } else {
            Record-Result $target 2 "Output files not found"
            Write-Failure "Windows x86: Output files not found"
        }
    } finally {
        Pop-Location
    }
}

function Build-LinuxX64 {
    $target = "linux-x64"
    Write-Info "Building Linux x64..."

    if (-not (Test-CanBuildLinux)) {
        Record-Result $target 3 "Linux build tools not available on this host"
        Write-Failure "Cannot build Linux x64: build tools not available"
        return
    }

    if ($HostOS -eq "windows") {
        Record-Result $target 3 "WSL integration not yet implemented in PowerShell script"
        Write-Failure "Linux x64: Use WSL directly or run this script in WSL"
        return
    }

    $buildPath = Join-Path $BuildDir "linux_x64"
    $outputPath = Join-Path $BinDir "Linux/x86_64"

    New-Item -ItemType Directory -Force -Path $buildPath | Out-Null
    New-Item -ItemType Directory -Force -Path $outputPath | Out-Null

    Push-Location $buildPath

    try {
        & cmake $ScriptDir `
            -DCMAKE_BUILD_TYPE=Release `
            -DCMAKE_C_FLAGS="-m64" `
            -DBUILD_SHARED_LIBS=ON `
            -DBUILD_STATIC_LIBS=ON

        if ($LASTEXITCODE -ne 0) {
            Record-Result $target 2 "CMake configuration failed"
            Write-Failure "Linux x64: CMake configuration failed"
            return
        }

        & make "-j$((Get-CimInstance -ClassName Win32_Processor).NumberOfLogicalProcessors)"

        if ($LASTEXITCODE -ne 0) {
            Record-Result $target 2 "Compilation failed"
            Write-Failure "Linux x64: Compilation failed"
            return
        }

        Copy-Item -Path "librnnoise.so*" -Destination $outputPath -Force -ErrorAction SilentlyContinue
        Copy-Item -Path "librnnoise.a" -Destination $outputPath -Force -ErrorAction SilentlyContinue

        if (Test-Path (Join-Path $outputPath "librnnoise.so")) {
            Record-Result $target 1 "Built successfully"
            Write-Success "Linux x64 built successfully"
        } else {
            Record-Result $target 2 "Output files not found"
            Write-Failure "Linux x64: Output files not found"
        }
    } finally {
        Pop-Location
    }
}

function Build-LinuxX86 {
    $target = "linux-x86"
    Write-Info "Building Linux x86..."

    Record-Result $target 3 "32-bit Linux builds only supported on native Linux"
    Write-Failure "Linux x86: Only supported on native Linux host with multilib"
}

function Build-AndroidArm64 {
    $target = "android-arm64"
    Write-Info "Building Android arm64-v8a..."

    if (-not (Test-CanBuildAndroid)) {
        Record-Result $target 3 "Android NDK not found"
        Write-Failure "Cannot build Android arm64: NDK not found"
        Write-Info "Set ANDROID_NDK_HOME or install NDK to common location"
        return
    }

    $outputPath = Join-Path $BinDir "Android\arm64-v8a"
    New-Item -ItemType Directory -Force -Path $outputPath | Out-Null

    $jniPath = Join-Path $ScriptDir "jni"
    Push-Location $jniPath

    try {
        $ndkBuild = if ($HostOS -eq "windows") {
            Join-Path $env:ANDROID_NDK_HOME "ndk-build.cmd"
        } else {
            Join-Path $env:ANDROID_NDK_HOME "ndk-build"
        }

        & $ndkBuild `
            NDK_PROJECT_PATH=. `
            APP_BUILD_SCRIPT=./Android.mk `
            APP_ABI=arm64-v8a `
            "NDK_LIBS_OUT=$BinDir/Android" `
            "NDK_OUT=$BuildDir/android_arm64"

        if ($LASTEXITCODE -ne 0) {
            Record-Result $target 2 "ndk-build failed"
            Write-Failure "Android arm64: ndk-build failed"
            return
        }

        if (Test-Path (Join-Path $outputPath "librnnoise.so")) {
            Record-Result $target 1 "Built successfully"
            Write-Success "Android arm64-v8a built successfully"
        } else {
            Record-Result $target 2 "Output files not found"
            Write-Failure "Android arm64: Output files not found"
        }
    } finally {
        Pop-Location
    }
}

function Build-AndroidArm32 {
    $target = "android-arm32"
    Write-Info "Building Android armeabi-v7a..."

    if (-not (Test-CanBuildAndroid)) {
        Record-Result $target 3 "Android NDK not found"
        Write-Failure "Cannot build Android arm32: NDK not found"
        Write-Info "Set ANDROID_NDK_HOME or install NDK to common location"
        return
    }

    $outputPath = Join-Path $BinDir "Android\armeabi-v7a"
    New-Item -ItemType Directory -Force -Path $outputPath | Out-Null

    $jniPath = Join-Path $ScriptDir "jni"
    Push-Location $jniPath

    try {
        $ndkBuild = if ($HostOS -eq "windows") {
            Join-Path $env:ANDROID_NDK_HOME "ndk-build.cmd"
        } else {
            Join-Path $env:ANDROID_NDK_HOME "ndk-build"
        }

        & $ndkBuild `
            NDK_PROJECT_PATH=. `
            APP_BUILD_SCRIPT=./Android.mk `
            APP_ABI=armeabi-v7a `
            "NDK_LIBS_OUT=$BinDir/Android" `
            "NDK_OUT=$BuildDir/android_arm32"

        if ($LASTEXITCODE -ne 0) {
            Record-Result $target 2 "ndk-build failed"
            Write-Failure "Android arm32: ndk-build failed"
            return
        }

        if (Test-Path (Join-Path $outputPath "librnnoise.so")) {
            Record-Result $target 1 "Built successfully"
            Write-Success "Android armeabi-v7a built successfully"
        } else {
            Record-Result $target 2 "Output files not found"
            Write-Failure "Android arm32: Output files not found"
        }
    } finally {
        Pop-Location
    }
}

function Build-MacOS {
    $target = "macos"
    Write-Info "Building macOS universal binary..."

    if (-not (Test-CanBuildMacOS)) {
        Record-Result $target 3 "macOS build tools not available (requires macOS)"
        Write-Failure "Cannot build macOS: requires macOS host"
        return
    }

    $buildPath = Join-Path $BuildDir "macos"
    $outputPath = Join-Path $BinDir "macOS"

    New-Item -ItemType Directory -Force -Path $buildPath | Out-Null
    New-Item -ItemType Directory -Force -Path $outputPath | Out-Null

    Push-Location $buildPath

    try {
        & cmake $ScriptDir `
            -DCMAKE_BUILD_TYPE=Release `
            -DCMAKE_OSX_ARCHITECTURES="x86_64;arm64" `
            -DBUILD_SHARED_LIBS=ON `
            -DBUILD_STATIC_LIBS=ON

        if ($LASTEXITCODE -ne 0) {
            Record-Result $target 2 "CMake configuration failed"
            Write-Failure "macOS: CMake configuration failed"
            return
        }

        & make "-j$((sysctl -n hw.ncpu))"

        if ($LASTEXITCODE -ne 0) {
            Record-Result $target 2 "Compilation failed"
            Write-Failure "macOS: Compilation failed"
            return
        }

        Copy-Item -Path "librnnoise.dylib" -Destination $outputPath -Force -ErrorAction SilentlyContinue
        Copy-Item -Path "librnnoise.a" -Destination $outputPath -Force -ErrorAction SilentlyContinue

        if (Test-Path (Join-Path $outputPath "librnnoise.dylib")) {
            Record-Result $target 1 "Built successfully"
            Write-Success "macOS universal binary built successfully"
        } else {
            Record-Result $target 2 "Output files not found"
            Write-Failure "macOS: Output files not found"
        }
    } finally {
        Pop-Location
    }
}

function Build-IOS {
    $target = "ios"
    Write-Info "Building iOS universal binary..."

    if (-not (Test-CanBuildIOS)) {
        Record-Result $target 3 "iOS build tools not available (requires macOS + Xcode)"
        Write-Failure "Cannot build iOS: requires macOS + Xcode"
        return
    }

    $buildPath = Join-Path $BuildDir "ios"
    $outputPath = Join-Path $BinDir "iOS"

    New-Item -ItemType Directory -Force -Path $buildPath | Out-Null
    New-Item -ItemType Directory -Force -Path $outputPath | Out-Null

    Push-Location $buildPath

    try {
        & cmake $ScriptDir `
            -G Xcode `
            -DCMAKE_SYSTEM_NAME=iOS `
            -DCMAKE_OSX_ARCHITECTURES="arm64" `
            -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 `
            -DCMAKE_BUILD_TYPE=Release `
            -DBUILD_SHARED_LIBS=OFF `
            -DBUILD_STATIC_LIBS=ON

        if ($LASTEXITCODE -ne 0) {
            Record-Result $target 2 "CMake configuration failed"
            Write-Failure "iOS: CMake configuration failed"
            return
        }

        & cmake --build . --config Release

        if ($LASTEXITCODE -ne 0) {
            Record-Result $target 2 "Compilation failed"
            Write-Failure "iOS: Compilation failed"
            return
        }

        Copy-Item -Path "Release\librnnoise.a" -Destination $outputPath -Force -ErrorAction SilentlyContinue

        if (Test-Path (Join-Path $outputPath "librnnoise.a")) {
            Record-Result $target 1 "Built successfully"
            Write-Success "iOS universal binary built successfully"
        } else {
            Record-Result $target 2 "Output files not found"
            Write-Failure "iOS: Output files not found"
        }
    } finally {
        Pop-Location
    }
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

Write-Header "RNNoise Universal Build Script (PowerShell)"

# Show help if requested or no arguments
if ($Help -or $PSBoundParameters.Count -eq 0) {
    Show-Help
    exit 0
}

# Process flag shortcuts
if ($Windows) {
    $WindowsX64 = $true
    $WindowsX86 = $true
}

if ($Linux) {
    $LinuxX64 = $true
    $LinuxX86 = $true
}

if ($Android) {
    $AndroidArm64 = $true
    $AndroidArm32 = $true
}

if ($All) {
    $WindowsX64 = $true
    $WindowsX86 = $true
    $LinuxX64 = $true
    $LinuxX86 = $true
    $AndroidArm64 = $true
    $AndroidArm32 = $true
    $MacOS = $true
    $IOS = $true
}

# Display host information
Write-Info "Host OS: $HostOS"
Write-Info "Script directory: $ScriptDir"
Write-Host ""

# Execute builds
if ($WindowsX64) { Build-WindowsX64 }
if ($WindowsX86) { Build-WindowsX86 }
if ($LinuxX64) { Build-LinuxX64 }
if ($LinuxX86) { Build-LinuxX86 }
if ($AndroidArm64) { Build-AndroidArm64 }
if ($AndroidArm32) { Build-AndroidArm32 }
if ($MacOS) { Build-MacOS }
if ($IOS) { Build-IOS }

# Display build report
Write-Header "BUILD REPORT"

foreach ($target in $BuildResults.Keys | Sort-Object) {
    $status = $BuildResults[$target]
    $message = $BuildMessages[$target]

    switch ($status) {
        1 {
            Write-Success "$target : $message"
            $script:SuccessCount++
        }
        2 {
            Write-Failure "$target : $message"
            $script:FailedCount++
        }
        3 {
            Write-Warning-Custom "$target : $message"
            $script:UnsupportedCount++
        }
    }
}

Write-Host ""
Write-Host "Summary:"
Write-Host "  Successful: $SuccessCount"
Write-Host "  Failed: $FailedCount"
Write-Host "  Unsupported: $UnsupportedCount"
Write-Host ""

if ($FailedCount -gt 0) {
    Write-Failure "Some builds failed!"
} elseif ($SuccessCount -gt 0) {
    Write-Success "All requested builds completed successfully!"
} else {
    Write-Warning-Custom "No builds were successful"
}

if ($FailedCount -gt 0) {
    exit 1
} else {
    exit 0
}
