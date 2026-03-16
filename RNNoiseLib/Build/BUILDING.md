# Building RNNoise

Cross-platform build system for Windows, Linux, macOS, Android, and iOS.

---

## Quick Start

**Have CMake and a C++ compiler?** Just run:

```bash
# Windows (PowerShell)
.\rnnoise-build.ps1 -All

# Linux/macOS/WSL
./rnnoise-build.sh --all
```

**Don't have build tools?** See [Prerequisites](#prerequisites) below.

**Output:** Check the `bin/` directory for your libraries.

---

## Prerequisites

### Windows
- **CMake** - [Download](https://cmake.org/download/) (check "Add to PATH")
- **Visual Studio 2017+** with "C++ Desktop Development" - [Download](https://visualstudio.microsoft.com/downloads/)
  - *Or* MinGW-w64 if you prefer
  - *Build script auto-detects Visual Studio, no setup needed*

### Linux/WSL
```bash
sudo apt update
sudo apt install cmake build-essential
```

### Android (Any OS)
1. Install [Android Studio](https://developer.android.com/studio)
2. SDK Manager → SDK Tools → Check "NDK (Side by side)" → Apply
3. **Find your NDK path**:
   - Windows: `.\find-ndk.ps1`
   - Linux/WSL: `./find-ndk.sh`
4. **Set environment variable**:
   ```bash
   export ANDROID_NDK_HOME="/path/to/ndk"  # WSL: /mnt/c/Users/YourName/AppData/Local/Android/Sdk/ndk/XX.X.XXXXXX
   ```

### macOS/iOS
```bash
xcode-select --install  # macOS only
# For iOS: Install full Xcode from App Store
```

---

## Usage

### Build Specific Platforms

```bash
# Windows
.\rnnoise-build.ps1 -Windows          # Both x64 and x86
.\rnnoise-build.ps1 -WindowsX64       # Just x64

# Linux (from WSL or Linux)
./rnnoise-build.sh --linux

# Android
.\rnnoise-build.ps1 -Android          # Windows
./rnnoise-build.sh --android          # Linux/WSL

# All platforms
.\rnnoise-build.ps1 -All
./rnnoise-build.sh --all
```

### Help
```bash
.\rnnoise-build.ps1 -Help
./rnnoise-build.sh --help
```

---

## Output

Libraries are in `bin/` directory:

```
bin/
├── Windows/x64/rnnoise.dll       ← Use this
├── Windows/x86/rnnoise.dll
├── Linux/x86_64/librnnoise.so    ← Use this
├── Android/arm64-v8a/librnnoise.so
└── Android/armeabi-v7a/librnnoise.so
```

**Note:** Linux builds also create `.so.1` and `.so.1.0.0` files (version-specific). You only need `librnnoise.so` for most uses.

---

## Troubleshooting

### Windows: "Build tools not available"

**Problem:** CMake or compiler not found.

**Fix:**
```powershell
# Check if installed
cmake --version

# If not found:
# 1. Download CMake from cmake.org (check "Add to PATH" during install)
# 2. Install Visual Studio with "C++ Desktop Development" workload
#    (build script auto-detects Visual Studio, no environment setup needed)

# Then run build again
.\rnnoise-build.ps1 -Windows
```

---

### Android: "NDK not found"

**Problem:** Android NDK not installed or `ANDROID_NDK_HOME` not set.

**Fix for Windows:**
```powershell
# Find NDK automatically
.\find-ndk.ps1

# It will tell you the path, then set it:
$env:ANDROID_NDK_HOME = "C:\Users\YourName\AppData\Local\Android\Sdk\ndk\XX.X.XXXXXX"

# Build
.\rnnoise-build.ps1 -Android
```

**Fix for WSL/Linux:**
```bash
# Find NDK automatically
./find-ndk.sh

# It will tell you the path, then set it:
export ANDROID_NDK_HOME="/path/shown/by/script"

# Or for WSL accessing Windows NDK:
export ANDROID_NDK_HOME="/mnt/c/Users/YourName/AppData/Local/Android/Sdk/ndk/XX.X.XXXXXX"

# Build
./rnnoise-build.sh --android
```

**Don't have NDK?**
- Install Android Studio → SDK Manager → SDK Tools → "NDK (Side by side)"

---

### Linux: "Build tools not available"

**Problem:** CMake or GCC not installed in WSL/Linux.

**Fix:**
```bash
sudo apt update
sudo apt install cmake build-essential
```

---

### WSL: "bash\r: No such file or directory"

**Problem:** Windows line endings in shell script.

**Fix:**
```bash
dos2unix rnnoise-build.sh
# Or: sed -i 's/\r$//' rnnoise-build.sh
./rnnoise-build.sh --linux
```

---

### Other Issues

**Visual Studio installed but not detected?**
- Open Visual Studio Installer → Modify → Check "Desktop development with C++"

**Permission denied (Linux/macOS)?**
```bash
chmod +x rnnoise-build.sh
```

**Build succeeds but no output files?**
- Check `bin/` directory structure
- Verify write permissions
- Scroll up in output for errors

---

## Platform Support

| Build From | Windows | Linux | Android | macOS | iOS |
|------------|---------|-------|---------|-------|-----|
| **Windows** | ✓ | ✓ (via WSL) | ✓ | ✗ | ✗ |
| **Linux** | ✗ | ✓ | ✓ | ✗ | ✗ |
| **macOS** | ✗ | ✗ | ✓ | ✓ | ✓ |

---

## Helper Scripts

### Finding Android NDK

**Windows:**
```powershell
.\find-ndk.ps1
```

**Linux/WSL/macOS:**
```bash
./find-ndk.sh
```

Both scripts show:
- Where NDK is installed
- Exact path to use
- Command to set `ANDROID_NDK_HOME`
- Current environment variable status

---

## Advanced

### Directory Structure

```
Build/
├── rnnoise-build.ps1      # PowerShell build script
├── rnnoise-build.sh       # Shell build script
├── find-ndk.ps1           # NDK finder (Windows)
├── find-ndk.sh            # NDK finder (Linux/WSL/macOS)
├── bin/                   # Final output (use these!)
│   ├── Windows/
│   ├── Linux/
│   └── Android/
└── intermediate/          # Temporary build files (can delete)
```

### For Unity Projects

Copy libraries to `Assets/Plugins/`:

```
Assets/Plugins/
├── Android/libs/
│   ├── arm64-v8a/librnnoise.so
│   └── armeabi-v7a/librnnoise.so
├── iOS/librnnoise.a
└── x86_64/
    ├── rnnoise.dll          # Windows
    ├── librnnoise.so        # Linux
    └── librnnoise.dylib     # macOS
```

### CI/CD

Scripts return exit codes:
- `0` = Success
- `1` = Failure

**GitHub Actions Example:**
```yaml
- name: Build Windows
  run: .\rnnoise-build.ps1 -Windows

- name: Build Linux
  run: |
    sudo apt install cmake build-essential
    ./rnnoise-build.sh --linux
```

### Custom CMake Build

For advanced users:

```bash
mkdir custom-build && cd custom-build
cmake .. -DCMAKE_BUILD_TYPE=Debug -DBUILD_SHARED_LIBS=ON
cmake --build . --config Debug
```

---

## FAQ

**Q: Do I need Visual Studio or just the compiler?**
A: Build Tools for Visual Studio (lighter) works fine. No IDE needed.

**Q: Can I build Android from WSL?**
A: Yes! Set `ANDROID_NDK_HOME` to your Windows NDK path using `/mnt/c/...` format.

**Q: Which .so file do I use for Linux?**
A: Use `librnnoise.so` (the unversioned one). Ignore `.so.1` and `.so.1.0.0`.

**Q: Why "build tools not available" when I have them installed?**
A: Ensure they're in your PATH. For Visual Studio, the script auto-detects it even if `cl.exe` isn't in PATH.

**Q: How do I build just one architecture?**
A: Use specific flags: `-WindowsX64`, `--linux-x64`, `--android-arm64`, etc.

**Q: Can I delete the `intermediate/` directory?**
A: Yes, it's temporary build files. Final outputs are in `bin/`.

---

## Getting Help

1. **Check error message** - Usually tells you what's missing
2. **Verify prerequisites** - Run `cmake --version`, `gcc --version`, etc.
3. **Find Android NDK** - Run `.\find-ndk.ps1` (Windows) or `./find-ndk.sh` (Linux)
4. **Still stuck?** - Check [Troubleshooting](#troubleshooting) section above

---

## Summary

**Two scripts, works everywhere:**
```bash
.\rnnoise-build.ps1 -All    # PowerShell (Windows, or cross-platform with PowerShell Core)
./rnnoise-build.sh --all    # Bash (Linux, macOS, WSL)
```

**Most common issues:**
1. Missing build tools → Install CMake + Visual Studio/GCC
2. Android NDK not found → Run `.\find-ndk.ps1`, set `ANDROID_NDK_HOME`
3. WSL line endings → Run `dos2unix rnnoise-build.sh`

**Get building in under 2 minutes!** 🚀
