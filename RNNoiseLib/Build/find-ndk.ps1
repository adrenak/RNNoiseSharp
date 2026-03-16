Write-Host 'Searching for Android NDK...' -ForegroundColor Cyan
Write-Host ''

# Check common locations
$locations = @(
    "$env:LOCALAPPDATA\Android\Sdk\ndk",
    "$env:USERPROFILE\Android\Sdk\ndk",
    "C:\Android\Sdk\ndk",
    "C:\Android\ndk",
    "D:\Android\Sdk\ndk",
    "D:\Android\ndk"
)

$found = $false
$ndkPaths = @()

foreach ($loc in $locations) {
    if (Test-Path $loc) {
        Write-Host "Found NDK location: $loc" -ForegroundColor Green
        $versions = Get-ChildItem $loc -Directory -ErrorAction SilentlyContinue
        foreach ($ver in $versions) {
            Write-Host "  - $($ver.Name)" -ForegroundColor Cyan
            $ndkPaths += $ver.FullName
        }
        $found = $true
    }
}

if (-not $found) {
    Write-Host 'No Android NDK found in common locations' -ForegroundColor Yellow
    Write-Host ''
    Write-Host 'You need to install the Android NDK. Options:' -ForegroundColor Yellow
    Write-Host '1. Via Android Studio: Tools -> SDK Manager -> SDK Tools -> NDK'
    Write-Host '2. Download standalone: https://developer.android.com/ndk/downloads'
} else {
    Write-Host ''
    Write-Host "Found $($ndkPaths.Count) NDK installation(s)" -ForegroundColor Green
    if ($ndkPaths.Count -gt 0) {
        $latest = $ndkPaths[-1]
        Write-Host ''
        Write-Host "Recommended NDK path to use:" -ForegroundColor Yellow
        Write-Host "  $latest" -ForegroundColor Cyan
        Write-Host ''
        Write-Host "To set ANDROID_NDK_HOME, run:" -ForegroundColor Yellow
        Write-Host "  `$env:ANDROID_NDK_HOME = `"$latest`"" -ForegroundColor Green
        Write-Host ''
        Write-Host "Or set it permanently in System Environment Variables" -ForegroundColor Yellow
    }
}

# Check if ANDROID_NDK_HOME is already set
Write-Host ''
Write-Host 'Current ANDROID_NDK_HOME setting:' -ForegroundColor Cyan
if ($env:ANDROID_NDK_HOME) {
    Write-Host "  $env:ANDROID_NDK_HOME" -ForegroundColor Green
    if (Test-Path $env:ANDROID_NDK_HOME) {
        Write-Host '  Status: Path exists ✓' -ForegroundColor Green
    } else {
        Write-Host '  Status: Path does NOT exist ✗' -ForegroundColor Red
    }
} else {
    Write-Host '  (Not set)' -ForegroundColor Gray
}
