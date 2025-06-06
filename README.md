# LoopSmith

This project provides tools for seamless looping of audio files.

## Features
- Import multiple audio files, adjust fade lengths and preview loops.
 - Crossfade mode combobox selects between Manual, Beat Detection or Spectral modes.
- BPM detection and automatic fade adjustment to match one measure.
- Simple auto-quantization of loops on export.

## Building
This project targets macOS and requires the macOS SDK. Use Xcode or the Swift
package manager on macOS to build.

## License
This project is released under the [MIT License](LICENSE).

## Packaging and Release
1. **Archive the App**
   - Use Xcode's *Product → Archive* menu or run `xcodebuild -scheme LoopSmith archive` to build a release archive.
2. **Create the DMG**
   - After building, package the application by creating a disk image:
     ```bash
     hdiutil create -fs HFS+ -srcfolder Path/To/LoopSmith.app LoopSmith.dmg
     ```
3. **Publish**
   - Upload `LoopSmith.dmg` to a new release on GitHub under the *Releases* section.
