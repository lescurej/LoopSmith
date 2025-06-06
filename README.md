# LoopSmith

LoopSmith is a SwiftUI application for creating seamless audio loops on macOS.
It provides a simple interface to import audio, fine‑tune cross‑fades and export
ready‑to‑use loop files.

## Key Features
- Drag and drop or use the **Import** button to add multiple audio files at
  once.
- Adjustable fade lengths with real‑time waveform preview.
- Crossfade modes: **Manual**, **Beat Detection** and **Spectral**.
- Built‑in BPM detection to align fades to the nearest musical measure.
- Live loop preview with progress indicators during export.
- Output formats: WAV or AIFF. Exported files are prefixed with `LOOP_`.

## Usage
1. Launch the application on macOS.
2. Import audio files via **Import** or by dragging them onto the list.
3. Set the fade percentage and choose a crossfade mode for each file.
4. Press the preview button to audition the loop.
5. Click **Export files** to choose an output directory and start processing.
6. Once complete, use **Open Folder** to reveal the exported loops in Finder.

## Building from Source
The project targets macOS 12 or later. Open `LoopSmith.xcodeproj` in Xcode and
build the app, or use the Swift Package Manager:

```bash
swift build
```

The `Package.swift` manifest declares a single executable target named
`LoopSmith`.

## Repository Layout
- `LoopSmith/` – Swift sources for the main application.
- `LoopSmith.xcodeproj` – Xcode project files.
- `Assets.xcassets` – Icons and other assets.
- `Preview Content` – Resources used for SwiftUI previews.

## License
LoopSmith is released under the [MIT License](LICENSE).

## Packaging and Release
1. **Archive the App**
   - Use Xcode's *Product → Archive* menu or run `xcodebuild -scheme LoopSmith archive` to create a release archive.
2. **Create the DMG**
   - After building, package the application by creating a disk image:
     ```bash
     hdiutil create -fs HFS+ -srcfolder Path/To/LoopSmith.app LoopSmith.dmg
     ```
3. **Publish**
   - Upload `LoopSmith.dmg` to a new release on GitHub under the *Releases* section.
