import Foundation
import UniformTypeIdentifiers
import AVFoundation

struct AudioFileItem: Identifiable {
    let id = UUID()
    let url: URL
    let fileName: String
    var duration: TimeInterval
    var fadeDurationMs: Double
    var progress: Double = 0.0
    let format: AudioFileFormat
    
    var durationString: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    init(url: URL, fadeDurationMs: Double, duration: TimeInterval) {
        self.url = url
        self.fileName = url.lastPathComponent
        self.fadeDurationMs = fadeDurationMs
        guard let format = AudioFileFormat(url: url) else {
            fatalError("Format audio non supporté")
        }
        self.format = format
        self.duration = duration
    }
    
    static func load(url: URL, fadeDurationMs: Double, completion: @escaping (AudioFileItem?) -> Void) {
        let asset = AVURLAsset(url: url)
        if #available(macOS 13.0, *) {
            Task {
                do {
                    let duration = try await asset.load(.duration)
                    let seconds = CMTimeGetSeconds(duration)
                    DispatchQueue.main.async {
                        completion(AudioFileItem(url: url, fadeDurationMs: fadeDurationMs, duration: seconds))
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            }
        } else {
            asset.loadValuesAsynchronously(forKeys: ["duration"]) {
                var error: NSError? = nil
                let status = asset.statusOfValue(forKey: "duration", error: &error)
                if status == .loaded {
                    let duration = CMTimeGetSeconds(asset.duration)
                    DispatchQueue.main.async {
                        completion(AudioFileItem(url: url, fadeDurationMs: fadeDurationMs, duration: duration))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            }
        }
    }
}

enum AudioFileFormat: String, CaseIterable {
    case wav, aiff, mp3
    
    static var allowedUTTypes: [UTType] {
        [UTType.wav, UTType.aiff, UTType.mp3]
    }
    
    init?(url: URL) {
        switch url.pathExtension.lowercased() {
        case "wav": self = .wav
        case "aiff", "aif": self = .aiff
        case "mp3": self = .mp3
        default: return nil
        }
    }
}
