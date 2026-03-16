#!/bin/bash

echo "Searching for Android NDK..."
echo ""

# Common NDK locations for Linux/macOS
ndk_locations=(
    "$HOME/Android/Sdk/ndk"
    "$HOME/android-ndk"
    "$ANDROID_HOME/ndk"
    "/opt/android-ndk"
)

# If running from WSL, also check Windows paths
if [[ -d "/mnt/c/Users" ]]; then
    echo "WSL detected - also checking Windows locations..."
    for user_dir in /mnt/c/Users/*/AppData/Local/Android/Sdk/ndk; do
        if [[ -d "$user_dir" ]]; then
            ndk_locations+=("$user_dir")
        fi
    done
fi

# Search for NDK installations
found_ndks=()

for location in "${ndk_locations[@]}"; do
    if [[ -d "$location" ]]; then
        # Find all NDK versions in this location
        for ndk_dir in "$location"/*; do
            if [[ -d "$ndk_dir" ]] && [[ -f "$ndk_dir/ndk-build" || -f "$ndk_dir/ndk-build.cmd" ]]; then
                found_ndks+=("$ndk_dir")
            fi
        done
    fi
done

# Display results
if [[ ${#found_ndks[@]} -eq 0 ]]; then
    echo "No Android NDK found in common locations"
    echo ""
    echo "You need to install the Android NDK. Options:"
    echo "1. Via Android Studio: Tools -> SDK Manager -> SDK Tools -> NDK"
    echo "2. Download standalone: https://developer.android.com/ndk/downloads"
    exit 1
fi

echo "Found ${#found_ndks[@]} NDK installation(s):"
echo ""

for ndk_path in "${found_ndks[@]}"; do
    ndk_version=$(basename "$ndk_path")
    echo "  - $ndk_version"
    echo "    Path: $ndk_path"
done

echo ""
echo "Recommended NDK path to use:"
latest_ndk="${found_ndks[-1]}"
echo "  $latest_ndk"
echo ""

echo "To set ANDROID_NDK_HOME, run:"
echo "  export ANDROID_NDK_HOME=\"$latest_ndk\""
echo ""

echo "Or to make it permanent, add to ~/.bashrc:"
echo "  echo 'export ANDROID_NDK_HOME=\"$latest_ndk\"' >> ~/.bashrc"
echo "  source ~/.bashrc"
echo ""

# Check current setting
echo "Current ANDROID_NDK_HOME setting:"
if [[ -n "$ANDROID_NDK_HOME" ]]; then
    echo "  $ANDROID_NDK_HOME"
    if [[ -d "$ANDROID_NDK_HOME" ]]; then
        echo "  Status: Path exists [OK]"
    else
        echo "  Status: Path does NOT exist [ERROR]"
    fi
else
    echo "  (Not set)"
fi
