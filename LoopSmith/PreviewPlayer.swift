import Foundation
import AVFoundation
import SwiftUI
import CryptoKit

private struct PreviewCache {
    private static func key(for file: AudioFileItem) -> String {
        "\(file.url.path)-\(file.fadeDurationMs)-\(file.analyzePerfectPoint)"
    }

    private static func hash(_ string: String) -> String {
        let digest = SHA256.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func cached(file: AudioFileItem) -> (url: URL, center: Double)? {
        let path = url(for: file)
        let meta = path.appendingPathExtension("meta")
        guard FileManager.default.fileExists(atPath: path.path),
              let data = try? Data(contentsOf: meta),
              let string = String(data: data, encoding: .utf8),
              let center = Double(string) else { return nil }
        return (path, center)
    }

    static func store(file: AudioFileItem, url: URL, center: Double) {
        let meta = url.appendingPathExtension("meta")
        try? String(center).data(using: .utf8)?.write(to: meta)
    }

    static func url(for file: AudioFileItem) -> URL {
        let hashed = hash(key(for: file))
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("preview_" + hashed)
            .appendingPathExtension(file.format.rawValue)
    }
}

class PreviewPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying: Bool = false
    private var player: AVAudioPlayer?
    private var timer: Timer?

    func play(url: URL, startTime: TimeInterval? = nil, duration: TimeInterval? = nil) {
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            if let start = startTime {
                player?.currentTime = start
            }
            player?.play()
            isPlaying = true

            if let dur = duration {
                timer?.invalidate()
                timer = Timer.scheduledTimer(withTimeInterval: dur, repeats: false) { [weak self] _ in
                    self?.stop()
                }
            }
        } catch {
            print("PreviewPlayer error:", error)
            isPlaying = false
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        player?.stop()
        player = nil
        isPlaying = false
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stop()
    }
}

struct PreviewButton: View {
    var file: AudioFileItem
    @StateObject private var player = PreviewPlayer()
    @State private var isProcessing = false

    var body: some View {
        Button(action: toggle) {
            if isProcessing {
                ProgressView()
            } else {
                Text(player.isPlaying ? "Stop" : "Preview")
            }
        }
        .disabled(isProcessing)
    }

    private func toggle() {
        if player.isPlaying {
            player.stop()
            return
        }

        if let cached = PreviewCache.cached(file: file) {
            let fadeSeconds = file.fadeDurationMs / 1000
            let start = max(0, cached.center - fadeSeconds / 2)
            self.player.play(url: cached.url, startTime: start, duration: fadeSeconds)
            self.isProcessing = false
            return
        }

        isProcessing = true
        let tmpURL = PreviewCache.url(for: file)

        SeamlessProcessor.process(
            inputURL: file.url,
            outputURL: tmpURL,
            fadeDurationMs: file.fadeDurationMs,
            format: file.format,
            analyzePerfectPoint: file.analyzePerfectPoint,
            progress: nil
        ) { result in
            DispatchQueue.main.async {
                self.isProcessing = false
                switch result {
                case .success(let centerTime):
                    PreviewCache.store(file: file, url: tmpURL, center: centerTime)
                    let fadeSeconds = file.fadeDurationMs / 1000
                    let start = max(0, centerTime - fadeSeconds / 2)
                    self.player.play(url: tmpURL, startTime: start, duration: fadeSeconds)
                case .failure(let error):
                    print("Preview processing error:", error)
                }
            }
        }
    }
}
