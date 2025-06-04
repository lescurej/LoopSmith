import Foundation
import AVFoundation
import SwiftUI

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

        isProcessing = true
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(file.format.rawValue)

        SeamlessProcessor.process(
            inputURL: file.url,
            outputURL: tmpURL,
            fadeDurationMs: file.fadeDurationMs,
            format: file.format,
            rhythmSync: file.rhythmSync,
            progress: nil
        ) { result in
            DispatchQueue.main.async {
                self.isProcessing = false
                switch result {
                case .success(let centerTime):
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
