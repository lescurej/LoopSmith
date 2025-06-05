import Foundation
import UniformTypeIdentifiers
import AVFoundation
import Accelerate

struct AudioFileItem: Identifiable {
    let id = UUID()
    let url: URL
    let fileName: String
    var duration: TimeInterval
    var fadeDurationMs: Double
    var progress: Double = 0.0
    var exportedURL: URL? = nil
    var waveform: [Float] = []
    var analyzePerfectPoint: Bool = false
    let format: AudioFileFormat

    /// Returns the output URL for this file when exported to the given directory
    /// in the specified format. The name is generated once here to centralise the logic.
    func outputURL(in directory: URL, format: AudioFileFormat) -> URL {
        let baseName = fileName.replacingOccurrences(of: "." + self.format.rawValue, with: "")
        let outputFileName = "LOOP_" + baseName + "." + format.rawValue
        return directory.appendingPathComponent(outputFileName)
    }
    
    var durationString: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    init(url: URL, fadeDurationMs: Double, duration: TimeInterval, waveform: [Float] = [], analyzePerfectPoint: Bool = false) {
        self.url = url
        self.fileName = url.lastPathComponent
        self.fadeDurationMs = fadeDurationMs
        guard let format = AudioFileFormat(url: url) else {
            fatalError("Unsupported audio format")
        }
        self.format = format
        self.duration = duration
        self.waveform = waveform
        self.analyzePerfectPoint = analyzePerfectPoint
    }
    
    static func load(url: URL, completion: @escaping (AudioFileItem?) -> Void) {
        let asset = AVURLAsset(url: url)
        if #available(macOS 13.0, *) {
            Task {
                do {
                    let duration = try await asset.load(.duration)
                    let seconds = CMTimeGetSeconds(duration)
                    let fadeDurationMs = seconds * 1000 * 0.15
                    let waveform = generateWaveform(url: url)
                    DispatchQueue.main.async {
                        completion(AudioFileItem(url: url, fadeDurationMs: fadeDurationMs, duration: seconds, waveform: waveform))
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
                    let fadeDurationMs = duration * 1000 * 0.15
                    let waveform = generateWaveform(url: url)
                    DispatchQueue.main.async {
                        completion(AudioFileItem(url: url, fadeDurationMs: fadeDurationMs, duration: duration, waveform: waveform))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            }
        }
    }

    private static func generateWaveform(url: URL, samples: Int = 50) -> [Float] {
        guard let file = try? AVAudioFile(forReading: url),
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else {
            return []
        }

        do {
            try file.read(into: buffer)
        } catch {
            return []
        }

        guard let data = buffer.floatChannelData?[0] else { return [] }
        let frameCount = Int(buffer.frameLength)
        let step = max(1, frameCount / samples)
        var result: [Float] = []

        for i in stride(from: 0, to: frameCount, by: step) {
            let start = i
            let end = min(i + step, frameCount)
            var rms: Float = 0
            vDSP_measqv(data + start, 1, &rms, vDSP_Length(end - start))
            result.append(sqrt(rms))
        }

        let maxVal = result.max() ?? 1
        if maxVal > 0 {
            result = result.map { $0 / maxVal }
        }
        return result
    }
}

enum AudioFileFormat: String, CaseIterable {
    case wav, aiff
    
    static var allowedUTTypes: [UTType] {
        [UTType.wav, UTType.aiff, UTType.mp3]
    }
    
    init?(url: URL) {
        switch url.pathExtension.lowercased() {
        case "wav": self = .wav
        case "aiff", "aif": self = .aiff
        default: return nil
        }
    }
}
