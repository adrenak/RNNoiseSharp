# RNNoiseSharp for Unity

Unity-specific C# scripts for noise suppression using RNNoise.

## Installation

1. **Copy scripts to your Unity project**:
   ```
   Assets/Scripts/RNNoiseSharp/
   ├── Denoiser.cs
   └── RNNoiseSharpWrapper.cs
   ```

2. **Copy native libraries** from the prebuilt binaries:
   ```
   Assets/Plugins/
   ├── Android/
   │   ├── arm64-v8a/librnnoise.so
   │   └── armeabi-v7a/librnnoise.so
   ├── iOS/librnnoise.a
   └── x86_64/
       ├── rnnoise.dll          # Windows
       ├── librnnoise.so        # Linux
       └── librnnoise.dylib     # macOS
   ```

## Usage

```csharp
using RNNoiseSharp;
using System;

public class AudioNoiseReducer
{
    private Denoiser denoiser;

    void Start()
    {
        denoiser = new Denoiser();
    }

    void ProcessAudio(float[] audioData)
    {
        // Audio must be 48kHz, mono, float samples
        Span<float> buffer = new Span<float>(audioData);
        denoiser.Denoise(buffer);

        // audioData is now denoised (in-place)
    }

    void OnDestroy()
    {
        denoiser?.Dispose();
    }
}
```

## Requirements

- **Unity 2021.2+** (for `Span<T>` support with .NET Standard 2.1)
- **Audio format**: 48 kHz, mono, float samples (-1.0 to 1.0)
- **Allow unsafe code**: Project Settings → Player → Other Settings → Allow 'unsafe' Code

## Platform Support

| Platform | Architecture | Library Name |
|----------|--------------|--------------|
| Windows | x64, x86 | `rnnoise.dll` |
| Linux | x64, x86 | `librnnoise.so` |
| macOS | Universal | `librnnoise.dylib` |
| Android | arm64-v8a, armeabi-v7a | `librnnoise.so` |
| iOS | arm64 | `librnnoise.a` (static) |

The `RNNoiseSharpWrapper.cs` automatically handles platform-specific library loading using Unity compilation symbols (`UNITY_IOS` for iOS, `rnnoise` for all others).

## Notes

- RNNoise processes audio in **480-sample frames** (10ms at 48kHz)
- The `Denoiser` class handles buffering automatically
- Always call `Dispose()` when done to free native resources
- For non-48kHz audio, resample before processing

## Audio Format Conversion

If your audio is not in the correct format:

```csharp
// Convert int16[] to float[]
float[] ConvertToFloat(short[] int16Samples)
{
    float[] floatSamples = new float[int16Samples.Length];
    for (int i = 0; i < int16Samples.Length; i++)
    {
        floatSamples[i] = int16Samples[i] / 32768f;
    }
    return floatSamples;
}

// Convert float[] back to int16[]
short[] ConvertToInt16(float[] floatSamples)
{
    short[] int16Samples = new short[floatSamples.Length];
    for (int i = 0; i < floatSamples.Length; i++)
    {
        int16Samples[i] = (short)(floatSamples[i] * 32767f);
    }
    return int16Samples;
}
```

## Building Native Libraries

See [RNNoiseLib/Build/BUILDING.md](../../RNNoiseLib/Build/BUILDING.md) for instructions on building native libraries from source.
