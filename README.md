# RNNoiseSharp

.NET wrapper for [RNNoise] - a noise suppression library based on recurrent neural networks.

---

## Features

- **Cross-platform**: Windows, Linux, macOS, Android, iOS
- **Easy to build**: Automated build scripts for all platforms
- **Simple .NET API**: Easy-to-use C# wrapper for noise suppression
- **High quality**: Based on Xiph.org's RNNoise neural network
- **Real-time**: Processes 48 kHz, 16-bit mono PCM audio

---

## Quick Start

### 1. Build Native Libraries

```bash
# Windows (PowerShell)
cd RNNoiseLib/Build
.\rnnoise-build.ps1 -All

# Linux/macOS/WSL
cd RNNoiseLib/Build
./rnnoise-build.sh --all
```

Libraries will be in `RNNoiseLib/Build/bin/`

See **[RNNoiseLib/Build/BUILDING.md](RNNoiseLib/Build/BUILDING.md)** for prerequisites and detailed instructions.

### 2. For Unity Projects

1. **Build native libraries** (see above)
2. **Copy C# scripts** from `RNNoiseSharp/Unity/` to your Unity project
3. **Copy built libraries** from `RNNoiseLib/Build/bin/` to `Assets/Plugins/`

See **[RNNoiseSharp/Unity/README.md](RNNoiseSharp/Unity/README.md)** for detailed Unity setup.

### 3. For .NET Projects (Xamarin/MAUI)

1. **Build native libraries** (see above)
2. **Use the C# wrapper** from `RNNoiseSharp/Shared/`:

```csharp
using RNNoiseSharp;

var denoiser = new Denoiser();
Span<float> audioBuffer = GetAudioData(); // 48kHz mono float samples
denoiser.Denoise(audioBuffer);
denoiser.Dispose();
```

See `Sample/` directory for complete examples.

---

## Project Structure

```
RNNoiseSharp/
├── RNNoiseLib/           # Native RNNoise library
│   ├── Build/            # Build scripts and documentation
│   │   ├── BUILDING.md   # Detailed build guide
│   │   ├── rnnoise-build.ps1
│   │   ├── rnnoise-build.sh
│   │   ├── find-ndk.ps1
│   │   └── find-ndk.sh
│   ├── Source/           # RNNoise C source code
│   └── Include/          # Headers
├── RNNoiseSharp/         # C# wrappers
│   ├── Unity/            # Unity-specific scripts
│   │   ├── Denoiser.cs
│   │   ├── RNNoiseSharpWrapper.cs
│   │   └── README.md
│   └── Shared/           # Xamarin/MAUI wrapper
├── Sample/               # Example apps
└── README.md             # This file
```

---

## Supported Platforms

| Platform | Architectures | Status |
|----------|---------------|--------|
| Windows | x64, x86 | ✅ |
| Linux | x64, x86 | ✅ |
| Android | arm64-v8a, armeabi-v7a | ✅ |
| macOS | Universal (x64 + arm64) | ✅ |
| iOS | arm64 | ✅ |

---

## Audio Requirements

RNNoise processes audio with these specifications:
- **Format**: RAW 16-bit PCM (machine endian)
- **Sample Rate**: 48 kHz
- **Channels**: Mono

---

## License

**RNNoiseSharp** is licensed under [BSD-3-Clause]

I am not associated with [RNNoise].
All rights belong to their respective owners.

---

## Links

- [Unity Integration Guide](RNNoiseSharp/Unity/README.md)
- [Build Documentation](RNNoiseLib/Build/BUILDING.md)
- [Original RNNoise][RNNoise]

[BSD-3-Clause]: https://licenses.nuget.org/BSD-3-Clause
[RNNoise]: https://gitlab.xiph.org/xiph/rnnoise
