# LoopSmith

LoopSmith is a SwiftUI application for creating seamless audio loops on macOS.
It provides a simple interface for importing audio, refining crossfades, and exporting
ready-to-use loop files.

[![Download LoopSmith](https://img.shields.io/badge/Download-LoopSmith-blue)](https://github.com/lescurej/LoopSmith/releases/latest)

## Key Features
- Drag and drop or use the **Import** button to add multiple audio files simultaneously.
- Adjustable fade lengths with real-time waveform preview.
- Crossfade modes: **Manual**, **Tempo Detection**, and **Spectral**.
- Built-in BPM detection to align fades with the nearest musical measure.
- Live loop preview with progress indicators during export.
- Output formats: WAV or AIFF. Exported files are prefixed with `LOOP_`.

## System Requirements
- macOS 12.0 or later
- 4 GB RAM minimum recommended
- 100 MB available disk space

## Usage
1. Launch the application on macOS.
2. Import audio files via **Import** or by dragging them into the list.
3. Set the fade percentage and choose a crossfade mode for each file.
4. Press the preview button to listen to the loop.
5. Click **Export Files** to choose an output directory and start processing.
6. Once complete, use **Open Folder** to view the exported loops in Finder.

## Usage Tips
- For best results, use high-quality audio files (WAV, AIFF).
- Tempo detection works best with clear rhythmic files.
- Spectral mode is ideal for smooth transitions between different sounds.
- Use manual mode for precise control over transition points.

## Building from Source
The project targets macOS 12 or later. Open `LoopSmith.xcodeproj` in Xcode and
build the application, or use Swift Package Manager:

```bash
swift build
```

The `Package.swift` manifest declares a single executable target named
`LoopSmith`.

## Repository Structure
- `LoopSmith/` – Swift sources for the main application.
- `LoopSmith.xcodeproj` – Xcode project files.
- `Assets.xcassets` – Icons and other resources.
- `Preview Content` – Resources used for SwiftUI previews.

## License
LoopSmith is released under the [MIT License](LICENSE).

## Support and Contributing
- Report bugs and feature requests on [GitHub Issues](https://github.com/lescurej/LoopSmith/issues)
- Contributions are welcome! Check out our [contributing guide](CONTRIBUTING.md)
- For questions or support, open an issue on GitHub

## Website
A hosted copy of the documentation is available on the [project's GitHub Pages site](https://lescurej.github.io/LoopSmith/).
