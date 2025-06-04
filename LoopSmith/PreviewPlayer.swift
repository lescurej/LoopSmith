import Foundation
import AVFoundation
import SwiftUI

class PreviewPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying: Bool = false
    private var player: AVAudioPlayer?

    func play(url: URL) {
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.play()
            isPlaying = true
        } catch {
            print("PreviewPlayer error:", error)
            isPlaying = false
        }
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        self.player = nil
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
            progress: nil
        ) { result in
            DispatchQueue.main.async {
                self.isProcessing = false
                switch result {
                case .success:
                    self.player.play(url: tmpURL)
                case .failure(let error):
                    print("Preview processing error:", error)
                }
            }
        }
    }
}
